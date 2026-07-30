import SwiftUI

@main
struct ClaudeSessionViewApp: App {
    @State private var viewModel = UsageViewModel()
    @State private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView()
                .environment(viewModel)
                .environment(settings)
                .environment(\.locale, settings.language.locale ?? .autoupdatingCurrent)
                .preferredColorScheme(settings.theme.colorScheme)
        } label: {
            // "chart.bar.fill" plutôt qu'une jauge : une jauge se lit spontanément comme
            // "ce qu'il reste" (à la façon d'une jauge à essence), alors que ce % représente
            // par défaut ce qui a été consommé — l'icône doit renforcer ce sens, pas le contredire.
            switch settings.menuBarDisplay {
            case .iconOnly:
                Image(systemName: "chart.bar.fill")
            case .fiveHour, .sevenDay:
                Label(menuBarTitle, systemImage: "chart.bar.fill")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(settings)
                .environment(\.locale, settings.language.locale ?? .autoupdatingCurrent)
                .preferredColorScheme(settings.theme.colorScheme)
        }
    }

    private var menuBarTitle: String {
        let consumed: Double?
        switch settings.menuBarDisplay {
        case .fiveHour: consumed = viewModel.fiveHourPercent
        case .sevenDay: consumed = viewModel.weeklyPercent
        case .iconOnly: return ""
        }
        guard let consumed else { return "–" }
        let value = settings.showRemaining ? (100 - consumed) : consumed
        return "\(Int(value.rounded()))%"
    }
}
