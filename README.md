# HiddenApp

A lightweight macOS menu bar utility that hides other apps' status bar icons. A clean reimplementation of [Hidden Bar](https://github.com/dwarvesf/hidden) that fixes the ultrawide monitor bug. No Dock icon, minimal UI. Works on macOS 15 through 27.

## Install

### Requirements

- macOS 15 (Sequoia) or later
- Xcode 26.4 or later (to build from source)

### Homebrew

```bash
brew install --cask lucataco/tap/hiddenapp
```

### First-time setup

On first launch, HiddenApp shows a welcome popover that walks you through these steps:

1. After launching, you'll see two new items in your menu bar: a thin vertical line `|` (the separator) and a chevron `>` (the toggle).

2. **Arrange your icons**: Hold **Cmd** and drag menu bar icons you want to hide to the **left** of the `|` separator. Icons to the right of the separator stay visible.

3. **Click the chevron** `>` to hide. Click `<` to show again.

4. **Right-click the chevron** to access Preferences (auto-hide timer, launch at login), check for updates, or to Quit.

5. **Optional: Launch at Login** — Right-click the chevron > **Preferences...** > toggle **Launch at login**.

Tip: both menu bar items also have hover tooltips that explain what they do.

## Features

- **Single-click toggle** — left-click the chevron to hide/show icons
- **Right-click menu** — right-click (or Ctrl-click) the chevron for Preferences, Check for Updates, and Quit
- **Automatic updates** — checks daily via Sparkle and installs signed, notarized updates in place
- **First-run onboarding** — a one-time welcome popover explains the ⌘-drag setup
- **Auto-hide** — optionally auto-collapse icons after a configurable delay (2–60 seconds); waits until the pointer leaves the menu bar so icons aren't yanked away mid-use
- **Launch at Login** — via `SMAppService` (no helper app needed)
- **Ultrawide monitor support** — dynamically computes collapse width from the widest connected display. No hardcoded caps.
- **Multi-monitor aware** — recomputes on display connect/disconnect and resolution changes
- **Position persistence** — macOS remembers where you placed the separator across restarts via `autosaveName`
- **Menu-bar only** — no Dock icon, no main window (`LSUIElement = true`)

## The Ultrawide Fix

The original Hidden Bar caps its collapse width at 4000px, which isn't enough for ultrawide monitors (e.g., 5120x1440). Icons remain partially visible instead of being fully pushed off-screen.

HiddenApp fixes this by:
1. Using the **maximum width across all connected displays** (not just `NSScreen.main`)
2. Recomputing the collapse width **at collapse time**, not just at launch
3. Removing any artificial cap — a wider separator is harmless

## How It Works

HiddenApp places a separator (`|`) and a toggle chevron (`>`) in your menu bar. Drag any status bar icons you want to hide to the **left** of the separator. Click the chevron to collapse — the separator expands to push those icons off-screen. Click again to reveal them.

```
Icons visible:
[Apple] [App Menus] ... [hidden icons] [|] [>] [visible icons] [clock]

Icons hidden:
[Apple] [App Menus] ...                                  [<] [visible icons] [clock]
                        ^ pushed off-screen
```

The app creates two `NSStatusItem`s:

- **Toggle item** (created first, positioned further right): the `<`/`>` chevron button
- **Separator item** (created second, positioned to toggle's left): 20px wide. On macOS 15–26 it expands to `widestScreenWidth + 500px` when collapsing; on macOS 27+ it stays 20px and an overlay covers the extras to its left.

When you click the chevron to hide:

**macOS 15–26.** `separatorItem.length` is set to a large value (e.g. 5620px on a 5120px ultrawide). macOS clips status items that don't fit, so everything to the separator's left is pushed off the leading edge. The chevron flips from `>` to `<`.

**macOS 27+.** The menu bar is composited as a single WindowServer surface. An oversized status item no longer reflows the bar — it clamps and spills off the trailing edge, leaving hidden icons exactly where they were. HiddenApp therefore leaves the separator at 20px and covers **only the hidden extras packed against `|`** (Accessibility frames when granted; otherwise an 80pt strip). Empty extras stay native glass — no second plate over the notch. Clicks on the covered zone are swallowed. The chevron still flips from `>` to `<`.

When you click to show:
1. The overlay is removed (macOS 27+) or `separatorItem.length` is set back to 20px (earlier)
2. Icons are visible in the bar again
3. If auto-hide is enabled, a timer starts to re-collapse after the configured delay

No private APIs. No Accessibility permission. No Screen Recording. On macOS 27 the overlay windows are the supported substitute for a length trick the OS no longer honors.

## Build from source

1. Clone the repository:
   ```bash
   git clone https://github.com/lucataco/hiddenapp.git
   cd hiddenapp
   ```

2. Generate the Xcode project (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen)):
   ```bash
   brew install xcodegen
   ./scripts/generate-xcodeproj.sh
   ```

3. Open in Xcode:
   ```bash
   open hiddenapp.xcodeproj
   ```

4. Select the **hiddenapp** scheme, choose **My Mac** as the destination, and hit **Run** (Cmd+R).

5. The app appears in the menu bar — look for the `>` chevron and `|` separator.

### Building from the command line

```bash
./scripts/generate-xcodeproj.sh
xcodebuild -project hiddenapp.xcodeproj -scheme hiddenapp -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

### Running tests

```bash
xcodebuild -project hiddenapp.xcodeproj -scheme hiddenapp -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

## Updating

HiddenApp checks for updates automatically once a day via
[Sparkle](https://sparkle-project.org). Updates are EdDSA-signed and
notarized; the feed lives at `appcast.xml` on the `main` branch and is
updated by the release workflow. You can also check manually via
right-click > **Check for Updates…**.

Note for Homebrew users: the tap cask should declare `auto_updates true`
so `brew upgrade` doesn't fight Sparkle's in-place updates.

## Project Structure

```
hiddenapp/
  hiddenappApp.swift         App entry point (@main, NSApplicationDelegateAdaptor)
  AppDelegate.swift          Creates StatusBarController on launch
  StatusBarController.swift  Core logic: toggle + separator items, collapse/expand
  CollapseMode.swift         Length vs overlay collapse, by OS version
  OverlayRegion.swift        Overlay geometry (testable without NSScreen)
  CollapseOverlay.swift      macOS 27 compositor overlay that covers hidden icons
  AutoHideManager.swift      Configurable auto-collapse timer
  Preferences.swift          Unified UserDefaults wrapper (injectable for testing)
  PreferencesView.swift      SwiftUI popover for settings
  WelcomeView.swift          First-run onboarding popover
  Constants.swift            UserDefaults keys, separator dimensions
  Localizable.xcstrings      String catalog for localization
  PrivacyInfo.xcprivacy      Privacy manifest
  Info.plist                 Bundle metadata incl. Sparkle feed URL and update key
  hiddenapp.entitlements     App Sandbox + hardened runtime entitlements
  Assets.xcassets/           App icon assets
hiddenappTests/              Swift Testing unit tests
project.yml                  XcodeGen project definition
appcast.xml                  Sparkle update feed (updated by the release workflow)
scripts/
  generate-xcodeproj.sh      Regenerates hiddenapp.xcodeproj from project.yml
  update_appcast.py          Adds a signed release to appcast.xml
  update_homebrew_cask.py    Updates the Homebrew cask version and SHA256
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on building, testing, and submitting changes.

## License

MIT
