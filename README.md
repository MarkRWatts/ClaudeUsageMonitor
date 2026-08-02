# Claude Usage Monitor

A native macOS menu bar app that shows your Claude account's usage limits at a glance.

![Screenshot](screenshot.png)

- Menu bar icon: a hollow circle that fills white, clockwise from 12 o'clock, as your current
  5-hour session usage climbs from 0% to 100%.
- Click the icon for a breakdown of all three limits: the 5-hour session limit, the weekly
  all-model limit, and usage credits.
- A gear icon in that popover opens Settings: account details, current limits, a
  Launch at Login toggle, Sign Out, and Quit.

## How it works

There's no public Anthropic API for personal account usage stats. This app authenticates the
same way the claude.ai web app does (an embedded login window captures your session cookie,
stored in macOS Keychain) and calls the same internal endpoint claude.ai's own frontend uses:
`GET https://claude.ai/api/organizations/{organization_id}/usage`.

That endpoint is undocumented and unversioned — it could change or break without notice. This
is a personal utility built around it, not a supported integration.

## Building

Requires Xcode (full IDE, not just Command Line Tools) and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ClaudeUsageMonitor.xcodeproj -scheme ClaudeUsageMonitor -configuration Release build
```

The built `.app` will be under Xcode's DerivedData; copy it to `/Applications` for a stable,
permanent install (also avoids the ad-hoc code-signature changing — and Keychain re-prompting —
on every rebuild).

## Project layout

- `Auth/` — login window (`WKWebView`) and Keychain-backed credential storage.
- `Networking/` — the usage API client and response models.
- `MenuBar/` — the custom-drawn ring icon and `NSStatusItem` controller.
- `UI/` — SwiftUI views for the popover and settings window.
