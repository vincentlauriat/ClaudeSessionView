import SwiftUI

struct UsagePopoverView: View {
    @Environment(UsageViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Session Usage")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    windowCard(title: "Session (5h)", percent: viewModel.fiveHourPercent, resetsAt: viewModel.fiveHourResetsAt)
                    windowCard(title: "Semaine (7 jours)", percent: viewModel.weeklyPercent, resetsAt: viewModel.weeklyResetsAt)
                }
            }

            if let errorState = viewModel.errorState {
                let hasKnownValues = viewModel.fiveHourPercent != nil || viewModel.weeklyPercent != nil
                Text(errorMessage(errorState, hasKnownValues: hasKnownValues))
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
                Button("Rafraîchir", systemImage: "arrow.clockwise") { viewModel.refresh() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
            }

            Text("Source : compte Anthropic (api.anthropic.com/api/oauth/usage) — la même donnée que Claude Desktop.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Quitter", systemImage: "power") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.glass)
                .controlSize(.small)
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder
    private func windowCard(title: String, percent: Double?, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let percent {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(percent.rounded()))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(severityColor(percent))
                    Text("consommé")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(percent, 0), 100) / 100)
                    .tint(severityColor(percent))
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func severityColor(_ percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .orange
        default: return .red
        }
    }

    private func errorMessage(_ error: UsageFetchError, hasKnownValues: Bool) -> String {
        switch error {
        case .noCredentials:
            return "Identifiants Claude Code introuvables dans le Keychain."
        case .expiredCredentials:
            return "Session expirée — exécute `claude` une fois pour te reconnecter."
        case .rateLimited:
            return hasKnownValues ? "Limité temporairement par l'API — dernières valeurs connues affichées." : "Limité temporairement par l'API."
        case .network:
            return hasKnownValues ? "Erreur réseau — dernières valeurs connues affichées." : "Erreur réseau."
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
