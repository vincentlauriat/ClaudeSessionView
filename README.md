# ClaudeSessionView

A macOS menu bar app that shows your **real Anthropic account usage** — the percentage consumed of the current 5-hour session window and the 7-day weekly window, with an exact reset countdown. It reads the same data as Claude Desktop.

![Platform](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)
![Release](https://img.shields.io/github/v/release/vincentlauriat/ClaudeSessionView?sort=semver)

> The app queries the official endpoint `GET https://api.anthropic.com/api/oauth/usage`, authenticated with the OAuth token Claude Code itself stores in the macOS Keychain. That is exactly what Claude Code and Claude Desktop use internally — **not** an estimate or a local reconstruction.

## Screenshots

<!-- TODO: add real captures under docs/screenshots/ before publishing -->
| Menu bar | Popover | Settings |
|---|---|---|
| ![Menu bar](docs/screenshots/menubar.png) | ![Popover](docs/screenshots/popover.png) | ![Settings](docs/screenshots/settings.png) |

## Features

| Feature | Description |
|---|---|
| Real usage | 5-hour session and 7-day window percentages, straight from Anthropic's API |
| Reset countdown | Exact time until each window resets, plus the reset clock time |
| Menu bar display | Show the 5h %, the 7d %, or just the icon |
| Remaining vs consumed | Toggle whether percentages read as remaining or consumed |
| Launch at login | Start automatically when you log in (via `SMAppService`) |
| Localization | English, French, Chinese — switchable live, no relaunch |
| Theme | System, Light, or Dark — switchable live |
| Liquid Glass UI | Native macOS 26 design language |
| Honest errors | Explicit message when credentials are missing/expired or the API rate-limits, keeping the last known values on screen |

## Requirements

- **macOS 26.0 or later** (the UI uses the Liquid Glass APIs, which don't exist before macOS 26).
- **Claude Code** installed and signed in at least once on this machine — the app reuses the OAuth token it stores in the Keychain. It does not ask for your credentials and never stores them itself.

## Install

Download the latest signed & notarized DMG from the [Releases](https://github.com/vincentlauriat/ClaudeSessionView/releases) page, open it, and drag **ClaudeSessionView** to `/Applications`. The app lives in the menu bar (no Dock icon).

## Settings

Open the options window from the popover's **Settings…** button (or ⌘,):

- **Menu bar display** — `Session (5h)` / `Week (7 days)` / `Icon only`.
- **Show remaining instead of consumed** — flips the metric everywhere; the severity color stays keyed to consumed (red = danger).
- **Launch at login** — registers/unregisters the app with the system login items.
- **Language** — System / Français / English / 中文, applied immediately.
- **Theme** — System / Light / Dark, applied immediately.

## Build from source

```bash
brew install xcodegen        # if you don't have it
xcodegen generate
xcodebuild -scheme ClaudeSessionView -configuration Debug CODE_SIGNING_ALLOWED=NO build
open build/Debug/ClaudeSessionView.app   # or just run it from Xcode
```

A `Scripts/release.sh` script produces a signed & notarized DMG (Developer ID). See the script header for the required signing identity and notarization profile.

## Limitations (by design, not bugs)

- **Depends on the Claude Code Keychain entry.** If Claude Code has never run here, or the OAuth token expired without a recent `claude` invocation refreshing it, the app shows an explicit error instead of guessing a number.
- **No automatic OAuth refresh** — Claude Code refreshes the token during normal use; this app only reads it.
- **Polling every 5 minutes** (with exponential backoff on rate-limiting) to avoid getting rate-limited by the API itself.

## Architecture

SwiftUI `MenuBarExtra` + `Settings` scenes, `@Observable` state, direct HTTPS call to Anthropic's usage API. Full details in [`ARCHITECTURE_EN.md`](ARCHITECTURE_EN.md) (French mirror: [`ARCHITECTURE.md`](ARCHITECTURE.md)).

## License

[MIT](LICENSE) © 2026 Vincent Lauriat.

## Disclaimer

This is an unofficial, independent utility. It is not affiliated with, endorsed by, or supported by Anthropic. "Claude" is a trademark of Anthropic. It reads a token that Claude Code already stores locally and calls a documented-by-behavior endpoint; use it in accordance with Anthropic's terms of service.
