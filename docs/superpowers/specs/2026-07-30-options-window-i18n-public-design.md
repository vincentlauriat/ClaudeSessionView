# Design — Options window, localization & public release

Date: 2026-07-30
Status: Approved

## Goal

Add a Settings (options) window to ClaudeSessionView, introduce localization
(French / English / Chinese) and a theme selector, and prepare the project for a
public open-source release with high-quality documentation and a distributable,
signed & notarized DMG.

## Context

- macOS 26+ menu bar app (`MenuBarExtra`, `.window` style), Liquid Glass design.
- `LSUIElement = true` (no dock icon). Non-sandboxed (needs to read Claude Code's
  OAuth token from the Keychain).
- Currently: all UI strings hardcoded in French, no `Settings` scene, no
  localization, no theme control. Menu bar shows the 5h consumed percentage only.

## Settings model

A small `@Observable` `AppSettings` object, injected in the environment, backed by
`UserDefaults` (via `@AppStorage`-style keys). Five preferences:

| Setting            | Type                | Values                          | Default      |
|--------------------|---------------------|---------------------------------|--------------|
| Menu bar display   | enum `MenuBarDisplay` | `.fiveHour` / `.sevenDay` / `.iconOnly` | `.fiveHour` |
| Launch at login    | `Bool` (via `SMAppService`) | on / off                  | off          |
| Language           | enum `AppLanguage`  | `.system` / `.fr` / `.en` / `.zh` | `.system` |
| Theme              | enum `AppTheme`     | `.system` / `.light` / `.dark`  | `.system`    |
| Show remaining     | `Bool`              | remaining / consumed            | `false` (consumed) |

`Show remaining` flips the displayed metric (`100 - consumed`) in both the menu bar
and the popover, and adjusts the accompanying label ("restant" vs "consommé").

## Settings window

- New SwiftUI scene `Settings { SettingsView() }` → provides the standard
  "Settings…" entry (⌘,) and a real window even for an `LSUIElement` app.
- Opened from the popover via a "Réglages…" button using
  `@Environment(\.openSettings)` (macOS 14+).
- `SettingsView` is a `Form` with the five controls (Picker/Toggle) matching the
  table above, styled consistently with the Liquid Glass popover.

## Launch at login

- `SMAppService.mainApp.register()` / `.unregister()` (import `ServiceManagement`).
- The toggle reflects `SMAppService.mainApp.status`, re-read when the settings view
  appears. Non-sandboxed app → no additional helper target required.

## Localization

- All hardcoded French strings (popover, menu bar label, settings, error messages,
  reset countdown) extracted to a **String Catalog** `Localizable.xcstrings` with
  the three languages FR / EN / ZH.
- Live switching: `.environment(\.locale, …)` applied at the root of both scenes
  (popover + settings). The menu bar label, computed in the `App` struct, is
  resolved via `String(localized:locale:)` reading the selected locale.
- `.system` follows the OS language (no explicit locale override).

## Theme

- `.preferredColorScheme(…)` derived from `AppTheme`, applied at the root of both
  scenes. `.system` maps to `nil` (follow macOS appearance).

## Menu bar display logic

Driven by `MenuBarDisplay`:
- `.fiveHour` → 5h percentage (e.g. `45%`).
- `.sevenDay` → 7d percentage (e.g. `12%`).
- `.iconOnly` → icon only, no text.

The percentage respects the `Show remaining` setting. Semantics default to
"consumed" for continuity with the current design and the `chart.bar.fill` icon
rationale.

## Public release (second effort)

- `LICENSE` — MIT, Vincent Lauriat, 2026.
- `README.md` rewritten in English: features, screenshots, DMG install, build,
  limitations, stack, updated roadmap.
- `ARCHITECTURE_EN.md` updated + mirrored FR `ARCHITECTURE.md`.
- Screenshots generated from a running build; final images validated by the user.
- `Scripts/release.sh` per the standard pipeline: Developer ID `KFLACS69T9`,
  notarization profile `AppliMacVincentGithub`, DMG output in `release/`.

## Phases

1. `AppSettings` model + persistence.
2. Localization infrastructure (`Localizable.xcstrings` FR/EN/ZH + string extraction).
3. `SettingsView` + `Settings` scene + open button.
4. Wiring: theme + locale + menu bar display logic + launch at login.
5. Public release (LICENSE, README EN, ARCHITECTURE, `release.sh` + DMG).

## Non-goals

- OAuth token refresh (Claude Code owns that).
- Sandboxing the app (would break Keychain access).
- Languages beyond FR/EN/ZH.
