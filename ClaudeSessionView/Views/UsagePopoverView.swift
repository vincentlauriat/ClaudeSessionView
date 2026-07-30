import SwiftUI

struct UsagePopoverView: View {
    @Environment(UsageViewModel.self) private var viewModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Session Usage")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    windowCard(title: "Session (5h)", consumedPercent: viewModel.fiveHourPercent, resetsAt: viewModel.fiveHourResetsAt)
                    windowCard(title: "Week (7 days)", consumedPercent: viewModel.weeklyPercent, resetsAt: viewModel.weeklyResetsAt)
                }
            }

            if let errorState = viewModel.errorState {
                let hasKnownValues = viewModel.fiveHourPercent != nil || viewModel.weeklyPercent != nil
                errorText(errorState, hasKnownValues: hasKnownValues)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            HStack {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Checked \(lastUpdated.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { viewModel.refresh() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
            }

            Text("Source: Anthropic account (api.anthropic.com/api/oauth/usage) — the same data as Claude Desktop.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button("Settings…", systemImage: "gearshape") { openSettings() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                Spacer()
                Button("Quit", systemImage: "power") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder
    private func windowCard(title: LocalizedStringKey, consumedPercent: Double?, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let consumedPercent {
                let displayed = settings.showRemaining ? (100 - consumedPercent) : consumedPercent
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(displayed.rounded()))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(severityColor(consumedPercent))
                    Text(settings.showRemaining ? "remaining" : "consumed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(displayed, 0), 100) / 100)
                    .tint(severityColor(consumedPercent))
                if let resetsAt {
                    let duration = formatDuration(resetsAt.timeIntervalSinceNow)
                    let time = resetsAt.formatted(date: .omitted, time: .shortened)
                    Text("Resets in \(duration) (\(time))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Data unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // La couleur reste indexée sur le pourcentage CONSOMMÉ (rouge = danger),
    // que l'on affiche le consommé ou le restant.
    private func severityColor(_ consumedPercent: Double) -> Color {
        switch consumedPercent {
        case ..<50: return .green
        case ..<80: return .orange
        default: return .red
        }
    }

    @ViewBuilder
    private func errorText(_ error: UsageFetchError, hasKnownValues: Bool) -> some View {
        switch error {
        case .noCredentials:
            Text("Claude Code credentials not found in the Keychain.")
        case .expiredCredentials:
            Text("Session expired — run `claude` once to sign in again.")
        case .rateLimited:
            Text(hasKnownValues ? "Temporarily rate-limited by the API — showing last known values." : "Temporarily rate-limited by the API.")
        case .network:
            Text(hasKnownValues ? "Network error — showing last known values." : "Network error.")
        case .decodingFailed:
            Text("Unexpected response from the API.")
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
