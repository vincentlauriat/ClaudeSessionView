import SwiftUI

@main
struct ClaudeSessionViewApp: App {
    @State private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView()
                .environment(viewModel)
        } label: {
            // "chart.bar.fill" plutôt qu'une jauge : une jauge se lit spontanément comme
            // "ce qu'il reste" (à la façon d'une jauge à essence), alors que ce % représente
            // ce qui a été consommé — l'icône doit renforcer ce sens, pas le contredire.
            Label(menuBarTitle, systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        guard let percent = viewModel.fiveHourPercent else { return "–" }
        return "\(Int(percent.rounded()))% util."
    }
}
