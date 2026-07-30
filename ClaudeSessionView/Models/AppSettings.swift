import Foundation
import Observation
import ServiceManagement
import SwiftUI

/// Quelle information afficher dans le label de la barre de menu.
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case fiveHour
    case sevenDay
    case iconOnly

    var id: String { rawValue }
}

/// Langue de l'interface. `.system` suit la langue de macOS.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case french
    case english
    case chinese

    var id: String { rawValue }

    /// Locale à injecter dans l'environnement SwiftUI, ou `nil` pour suivre le système.
    var locale: Locale? {
        switch self {
        case .system: return nil
        case .french: return Locale(identifier: "fr")
        case .english: return Locale(identifier: "en")
        case .chinese: return Locale(identifier: "zh-Hans")
        }
    }
}

/// Thème d'apparence. `.system` suit l'apparence de macOS.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// ColorScheme à forcer, ou `nil` pour suivre le système.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Réglages utilisateur persistés dans `UserDefaults`, observables par l'UI.
///
/// Le lancement au démarrage n'est pas stocké dans `UserDefaults` : sa source de
/// vérité est `SMAppService.mainApp.status`. On l'expose comme une propriété
/// observable synchronisée avec le système.
@Observable
final class AppSettings {
    var menuBarDisplay: MenuBarDisplay {
        didSet { defaults.set(menuBarDisplay.rawValue, forKey: Keys.menuBarDisplay) }
    }

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// Afficher le pourcentage restant plutôt que consommé (barre de menu + popover).
    var showRemaining: Bool {
        didSet { defaults.set(showRemaining, forKey: Keys.showRemaining) }
    }

    /// Reflète et pilote `SMAppService.mainApp`. Écrire déclenche register/unregister.
    var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let menuBarDisplay = "menuBarDisplay"
        static let language = "language"
        static let theme = "theme"
        static let showRemaining = "showRemaining"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarDisplay = defaults.string(forKey: Keys.menuBarDisplay)
            .flatMap(MenuBarDisplay.init) ?? .fiveHour
        language = defaults.string(forKey: Keys.language)
            .flatMap(AppLanguage.init) ?? .system
        theme = defaults.string(forKey: Keys.theme)
            .flatMap(AppTheme.init) ?? .system
        showRemaining = defaults.bool(forKey: Keys.showRemaining)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Resynchronise le toggle avec l'état réel du système (à appeler à l'apparition
    /// de la fenêtre de réglages : l'utilisateur a pu changer ça ailleurs).
    func syncLaunchAtLoginStatus() {
        let enabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != enabled {
            launchAtLogin = enabled
        }
    }

    /// Applique l'état demandé de façon idempotente. En cas d'échec, resynchronise
    /// le toggle sur l'état réel pour ne pas mentir à l'utilisateur.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            let status = SMAppService.mainApp.status
            if enabled, status != .enabled {
                try SMAppService.mainApp.register()
            } else if !enabled, status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let actual = SMAppService.mainApp.status == .enabled
            if launchAtLogin != actual {
                launchAtLogin = actual
            }
        }
    }
}
