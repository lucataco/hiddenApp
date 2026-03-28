# HiddenApp

A lightweight macOS menu bar utility that hides other apps' status bar icons. A clean reimplementation of [Hidden Bar](https://github.com/dwarvesf/hidden) that fixes the ultrawide monitor bug. No Dock icon, minimal UI, native `NSStatusItem` behavior. Works seamlessly with macOS 26 Liquid Glass.

## Install

### Requirements

- macOS 26 (Tahoe) or later
- Xcode 26.4 or later (to build from source)

### Homebrew

```bash
brew install --cask lucataco/tap/hiddenapp
```

### First-time setup

1. After launching, you'll see two new items in your menu bar: a thin vertical line `|` (the separator) and a chevron `>` (the toggle).

2. **Arrange your icons**: Hold **Cmd** and drag menu bar icons you want to hide to the **left** of the `|` separator. Icons to the right of the separator stay visible.

3. **Click the chevron** `>` to hide. Click `<` to show again.

4. **Right-click the chevron** to access Preferences (auto-hide timer, launch at login) or to Quit.

5. **Optional: Launch at Login** — Right-click the chevron > **Preferences...** > toggle **Launch at login**.

## Features

- **Single-click toggle** — left-click the chevron to hide/show icons
- **Right-click menu** — right-click the chevron for Preferences and Quit
- **Auto-hide** — optionally auto-collapse icons after a configurable delay (2–60 seconds)
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
- **Separator item** (created second, positioned to toggle's left): normally 20px wide, expands to `widestScreenWidth + 500px` when collapsing

When you click the chevron to hide:
1. `separatorItem.length` is set to a large value (e.g., 5620px on a 5120px ultrawide)
2. macOS naturally clips status items that don't fit — everything to the separator's left is pushed off the left edge of the screen
3. The chevron flips from `>` to `<`

When you click to show:
1. `separatorItem.length` is set back to 20px
2. Icons slide back into view
3. If auto-hide is enabled, a timer starts to re-collapse after the configured delay

No private APIs. No custom windows. No overlay windows, no visual effect hacks.

## Build from source

1. Clone the repository:
   ```bash
   git clone https://github.com/lucataco/hiddenapp.git
   cd hiddenapp
   ```

2. Open in Xcode:
   ```bash
   open hiddenapp.xcodeproj
   ```

3. Select the **hiddenapp** scheme, choose **My Mac** as the destination, and hit **Run** (Cmd+R).

4. The app appears in the menu bar — look for the `>` chevron and `|` separator.

## Project Structure

```
hiddenapp/
  hiddenappApp.swift         App entry point (@main, NSApplicationDelegateAdaptor)
  AppDelegate.swift          Creates StatusBarController on launch
  StatusBarController.swift  Core logic: toggle + separator items, collapse/expand
  AutoHideManager.swift      Configurable auto-collapse timer
  PreferencesView.swift      SwiftUI popover for settings
  Constants.swift            UserDefaults keys, separator dimensions
  Assets.xcassets/           App icon assets
```

## License

MIT
