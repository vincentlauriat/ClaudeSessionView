import Foundation

struct RateLimitWindow {
    let percent: Double
    let resetsAt: Date?
}

struct RateLimitUsage {
    let fiveHour: RateLimitWindow?
    let sevenDay: RateLimitWindow?
}

enum UsageFetchError: Error, Equatable {
    case noCredentials
    case expiredCredentials
    case rateLimited
    case network
    case decodingFailed
}

enum UsageAPIClient {
    private struct WindowPayload: Decodable {
        let utilization: Double?
        let resetsAt: String?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    private struct ResponsePayload: Decodable {
        let fiveHour: WindowPayload?
        let sevenDay: WindowPayload?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    static func fetch(completion: @escaping (Result<RateLimitUsage, UsageFetchError>) -> Void) {
        // KeychainCredentials.read() est synchrone (SecItemCopyMatching peut bloquer, ex. sur une
        // invite d'accès Keychain) — on l'exécute hors du thread principal pour ne pas geler l'UI.
        DispatchQueue.global(qos: .userInitiated).async {
            guard let creds = KeychainCredentials.read() else {
                completion(.failure(.noCredentials))
                return
            }
            if let expiresAt = creds.expiresAt, expiresAt < Date() {
                completion(.failure(.expiredCredentials))
                return
            }

            var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10

            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil, let http = response as? HTTPURLResponse else {
                    completion(.failure(.network))
                    return
                }
                if http.statusCode == 429 {
                    completion(.failure(.rateLimited))
                    return
                }
                guard http.statusCode == 200, let data else {
                    completion(.failure(.network))
                    return
                }
                guard let payload = try? JSONDecoder().decode(ResponsePayload.self, from: data) else {
                    completion(.failure(.decodingFailed))
                    return
                }
                let usage = RateLimitUsage(
                    fiveHour: payload.fiveHour.flatMap(makeWindow),
                    sevenDay: payload.sevenDay.flatMap(makeWindow)
                )
                completion(.success(usage))
            }.resume()
        }
    }

    private static func makeWindow(_ payload: WindowPayload) -> RateLimitWindow? {
        guard let utilization = payload.utilization else { return nil }
        return RateLimitWindow(percent: utilization, resetsAt: parseDate(payload.resetsAt))
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        // Repli : le serveur renvoie parfois des secondes fractionnaires à précision plus fine
        // (ex. ".716759") que le formatter ci-dessus ne supporte pas. On retire uniquement la
        // partie fractionnaire juste après hh:mm:ss (pas ailleurs dans la chaîne) et on retente —
        // la précision sous-seconde est de toute façon inutile pour un countdown de reset.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stripped = string.replacingOccurrences(of: #"(\d{2}:\d{2}:\d{2})\.\d+"#, with: "$1", options: .regularExpression)
        return formatter.date(from: stripped)
    }
}
