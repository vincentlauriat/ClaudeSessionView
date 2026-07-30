import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Menu bar") {
                Picker("Menu bar display", selection: $settings.menuBarDisplay) {
                    Text("Session (5h)").tag(MenuBarDisplay.fiveHour)
                    Text("Week (7 days)").tag(MenuBarDisplay.sevenDay)
                    Text("Icon only").tag(MenuBarDisplay.iconOnly)
                }
                Toggle("Show remaining instead of consumed", isOn: $settings.showRemaining)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Appearance") {
                Picker("Language", selection: $settings.language) {
                    Text("System").tag(AppLanguage.system)
                    Text(verbatim: "Français").tag(AppLanguage.french)
                    Text(verbatim: "English").tag(AppLanguage.english)
                    Text(verbatim: "中文").tag(AppLanguage.chinese)
                }
                Picker("Theme", selection: $settings.theme) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
        .onAppear { settings.syncLaunchAtLoginStatus() }
    }
}
