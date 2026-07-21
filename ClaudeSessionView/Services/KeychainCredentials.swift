import Foundation

struct OAuthCredentials {
    let accessToken: String
    let expiresAt: Date?
}

enum KeychainCredentials {
    private static let serviceName = "Claude Code-credentials"

    static func read() -> OAuthCredentials? {
        readEntry(account: NSUserName()) ?? readEntry(account: nil)
    }

    private static func readEntry(account: String?) -> OAuthCredentials? {
        var arguments = ["find-generic-password", "-s", serviceName]
        if let account {
            arguments += ["-a", account]
        }
        arguments.append("-w")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let jsonData = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return nil }

        let creds = (parsed["claudeAiOauth"] as? [String: Any]) ?? parsed
        guard let accessToken = creds["accessToken"] as? String else { return nil }

        var expiresAt: Date?
        if let expiresAtMs = creds["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: expiresAtMs / 1000)
        }

        return OAuthCredentials(accessToken: accessToken, expiresAt: expiresAt)
    }
}
