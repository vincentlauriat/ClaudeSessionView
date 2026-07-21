import SwiftUI

struct UsagePopoverView: View {
    @Environment(UsageViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Session Usage")
                .font(.headline)

            windowSection(title: "Session (5h)", percent: viewModel.fiveHourPercent, resetsAt: viewModel.fiveHourResetsAt)
            Divider()
            windowSection(title: "Semaine (7 jours)", percent: viewModel.weeklyPercent, resetsAt: viewModel.weeklyResetsAt)

            if let errorState = viewModel.errorState {
                Divider()
                Text(errorMessage(errorState))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            HStack {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Vérifié \(lastUpdated.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rafraîchir") { viewModel.refresh() }
                    .font(.caption)
            }

            Text("Source : compte Anthropic (api.anthropic.com/api/oauth/usage) — la même donnée que Claude Desktop.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Quitter") { NSApplication.shared.terminate(nil) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder
    private func windowSection(title: String, percent: Double?, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let percent {
                Text("\(Int(percent.rounded()))% consommé")
                    .font(.title3)
                    .fontWeight(.bold)
                ProgressView(value: percent / 100)
                if let resetsAt {
                    Text("Reset dans \(formatDuration(resetsAt.timeIntervalSinceNow)) (\(resetsAt.formatted(date: .omitted, time: .shortened)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Données indisponibles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorMessage(_ error: UsageFetchError) -> String {
        switch error {
        case .noCredentials:
            return "Identifiants Claude Code introuvables dans le Keychain."
        case .expiredCredentials:
            return "Session expirée — exécute `claude` une fois pour te reconnecter."
        case .rateLimited:
            return "Limité temporairement par l'API — dernières valeurs connues affichées."
        case .network:
            return "Erreur réseau — dernières valeurs connues affichées."
        case .decodingFailed:
            return "Réponse inattendue de l'API."
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval / 60))
        let hours = total / 60
        let minutes = total % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))"
        }
        return "\(minutes)min"
    }
}
