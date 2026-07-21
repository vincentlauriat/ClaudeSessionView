import Foundation

struct OAuthCredentials {
    let accessToken: String
    let expiresAt: Date?
}

enum KeychainCredentials {
    private static let serviceName = "Claude Code-credentials"

    // Lit l'identifiant via le binaire `/usr/bin/security` (signé Apple) plutôt que
    // SecItemCopyMatching en direct : testé empiriquement, l'appel natif depuis ce binaire
    // ad-hoc (identité de signature non stable en dev) reste bloqué indéfiniment sur
    // l'autorisation Keychain d'un item créé par une autre app (Claude Code), alors que
    // `security` — dont l'ACL de l'item fait déjà confiance — répond immédiatement.
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
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Lire avant d'attendre la fin du process : readDataToEndOfFile() bloque jusqu'à ce
        // que le pipe soit fermé (donc jusqu'à la fin du process), ce qui évite l'inter-blocage
        // classique si la sortie dépassait un jour le buffer du pipe (~64 Ko).
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

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
