# ARCHITECTURE

## Overview

`ClaudeSessionView` is a macOS menu bar utility (SwiftUI `MenuBarExtra`, no dock icon, `LSUIElement`) that shows the real Anthropic account usage against the 5-hour session window and the 7-day weekly window. It calls the same official endpoint Claude Code and Claude Desktop themselves use — it is **not** a local reconstruction (see History below for the two abandoned approaches).

## Data flow

```
macOS Keychain ("Claude Code-credentials")
        │  (KeychainCredentials: /usr/bin/security find-generic-password)
        ▼
   OAuthCredentials (accessToken, expiresAt)
        │  (UsageAPIClient: GET https://api.anthropic.com/api/oauth/usage,
        │   Authorization: Bearer <token>, anthropic-beta: oauth-2025-04-20)
        ▼
   RateLimitUsage (fiveHour / sevenDay: percent, resetsAt)
        │  (UsageViewModel: 5-min refresh, exponential backoff on 429)
        ▼
  MenuBarExtra label (compact %) + UsagePopoverView (detail)
```

## Components

| File | Responsibility |
|---|---|
| `ClaudeSessionViewApp.swift` | `@main`, `MenuBarExtra` scene, compact label |
| `Services/KeychainCredentials.swift` | Reads the OAuth token Claude Code stores in the macOS Keychain |
| `Services/UsageAPIClient.swift` | Authenticated HTTPS call to Anthropic's real usage API + JSON decoding (`RateLimitUsage`, `RateLimitWindow`, `UsageFetchError`) |
| `ViewModels/UsageViewModel.swift` | Observable state, 5-minute refresh timer, exponential backoff on rate-limit (429) |
| `Views/UsagePopoverView.swift` | Detail UI: real percentages, progress bars, reset countdowns, error message when applicable |

## The real endpoint

`GET https://api.anthropic.com/api/oauth/usage`, authenticated with the same OAuth token Claude Code stores in the Keychain (service `"Claude Code-credentials"`, account = macOS username or service-only fallback). Required header: `anthropic-beta: oauth-2025-04-20`. Relevant response shape:

```json
{
  "five_hour": { "utilization": 26.0, "resets_at": "2026-07-20T16:59:59.716759+00:00" },
  "seven_day": { "utilization": 34.0, "resets_at": "2026-07-24T17:59:59.716783+00:00" }
}
```

Gotcha: `resets_at` carries variable sub-second precision (6 fractional digits observed) that `ISO8601DateFormatter` does not reliably parse with `.withFractionalSeconds`. The fractional part is stripped via regex before parsing — sub-second precision is useless for a reset countdown anyway.

The `is_active` field (per entry in the `limits` array) is deliberately **not** used to gate the display: the API's percentage is always shown as-is.

## Why this switch (history)

- **v1**: raw token sum (`input + output + cache_creation + cache_read`) reconstructed from local transcripts (`~/.claude/projects/**/*.jsonl`). Bug reported by Vincent ("calculs inexactes"): every message re-reads the entire cached context, so the sum counted the same content thousands of times (up to 1.65 billion "tokens" over 7 days).
- **v2**: fixed via USD-cost-weighted accounting using Anthropic's real pricing (cache read ×0.1, 1h write ×2, 5m write ×1.25), verified to the cent against `claude --output-format json`. Still fundamentally wrong: Vincent reported an 86% (app) vs 24% (Claude Desktop) discrepancy for the same window — proof that no local reconstruction, however correctly weighted, reflects Anthropic's actual (undocumented) rate-limit accounting mechanism.
- **v3 (current)**: local reconstruction dropped entirely in favor of calling the real API directly — the one Claude Code and Claude Desktop use internally. Verified via curl and by comparing logs from the compiled binary: percentages match Claude Desktop.

## Known limitations

- Depends on the OAuth token Claude Code stores in the Keychain — if Claude Code has never run on this machine, or the token expired without a recent `claude` invocation refreshing it, the app shows an explicit error rather than guessing a value.
- No automatic OAuth refresh: relies on Claude Code refreshing the Keychain entry during normal use.
- Polling capped at every 5 minutes with exponential backoff on 429, to avoid self-inflicted rate-limiting against the API itself.

## Stack & distribution

- SwiftUI `MenuBarExtra` (macOS 14+ only, no iOS target).
- XcodeGen (`project.yml`) for project generation.
- No App Sandbox: required to shell out to `/usr/bin/security` and read a Keychain item created by another application (Claude Code). Developer ID distribution planned, consistent with the rest of Vincent's macOS app fleet.
