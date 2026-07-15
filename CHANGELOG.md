# Changelog

All notable changes to HiddenApp are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-07-14

A UI/UX-focused release by Catacolabs: the app now explains itself.

### Added

- **First-run welcome popover** — on first launch, a one-time popover anchored
  to the chevron walks through the three things a new user needs to know:
  ⌘-drag icons to the left of the `|` separator, click the chevron to
  hide/show, right-click for Preferences. Previously this crucial setup step
  lived only in the README.
- **Tooltips** — hovering the chevron explains what a click will do (and that
  right-click opens preferences); hovering the separator explains the ⌘-drag
  gesture.
- **Usage tip in Preferences** — the preferences popover now includes the
  ⌘-drag hint, so the core interaction is discoverable even after onboarding.
- **Wrong-side separator alert** — if the `|` separator has been dragged to
  the wrong side of the chevron, clicking the chevron now shows an alert
  explaining how to fix it instead of silently doing nothing.
- **Catacolabs link** — the preferences popover footer links to
  [catacolabs.com](https://catacolabs.com).

### Changed

- **Auto-hide waits for you to finish** — the auto-hide timer no longer
  collapses icons while the pointer is in the menu bar (e.g. while another
  status item's menu is open). It re-checks every 2 seconds and collapses
  once the pointer leaves.
- **Preferences popover reveals icons** — opening Preferences now expands
  hidden icons so changes have visible feedback, and the auto-hide countdown
  pauses while the popover is open (it resumes on close).
- **Delay slider is labeled** — the auto-hide delay slider now shows its
  2s–60s range instead of an unlabeled track.
- Copyright updated to © 2026 Catacolabs.

## [1.1.0] - 2026-06-21

### Added

- **Unified Preferences model** — all user defaults are now read and written
  through a single `Preferences` class with injectable `UserDefaults`, making
  the codebase testable and consistent.
- **Auto-hide timer tolerance** — the timer now has a tolerance of at least
  0.5 seconds, letting the OS coalesce it with other work to save energy.
- **Accessibility support** — the toggle button, separator, and context menu
  items now have proper `accessibilityRole`, `accessibilityLabel`,
  `accessibilityHelp`, and `accessibilityValue` so VoiceOver users can
  understand and interact with them.
- **String catalog** (`Localizable.xcstrings`) — all user-facing strings are
  now wrapped in `String(localized:)` or `LocalizedStringKey`, ready for
  translation.
- **Structured logging** — `os.Logger` calls in `AppDelegate`,
  `AutoHideManager`, `PreferencesView`, and `StatusBarController` for
  debugging and diagnostics.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) — declares the UserDefaults
  usage reason required by macOS 15+.
- **App Sandbox entitlements** — the app now runs sandboxed with a hardened
  runtime.
- **XcodeGen project generation** — the `.xcodeproj` is now generated from
  `project.yml` via `scripts/generate-xcodeproj.sh`, eliminating merge
  conflicts and keeping the repo clean.
- **Unit tests** — `ConstantsTests`, `PreferencesTests`, and
  `AutoHideManagerTests` covering the model layer.
- **CI workflow** — builds Debug and Release configurations and runs tests on
  every push and pull request.
- **Release workflow** — signs with Developer ID Application, notarizes via
  App Store Connect API key, staples, creates GitHub releases, and
  auto-updates the Homebrew tap.
- **Homebrew tap auto-update** — `scripts/update_homebrew_cask.py` updates
  the cask version and SHA256 on release.
- **Contributing guide** (`CONTRIBUTING.md`) — instructions for building,
  testing, and releasing.

### Changed

- **Popover size fixed** — the preferences popover content view width (280pt)
  now matches the popover's `contentSize` width (280pt), eliminating a layout
  warning.
- **Screen width fallback** — the hardcoded `1728` magic number for screen
  width is now `Constants.fallbackScreenWidth`, documented and testable.
- **SMAppService errors surfaced** — when launch-at-login registration fails,
  the user now sees an `NSAlert` with the error instead of silent failure.
- **Preferences popover** — rewritten to use the new `Preferences` model
  instead of `@AppStorage`, matching the `AutoHideManager` lifecycle.
- **Context menu** — menu items use `String(localized:)` for localization.

### Fixed

- **Cancel pending collapse retry on quit** — `prepareForTermination()` now
  cancels any pending `DispatchWorkItem` retry, preventing a crash if the app
  quits while a retry is queued.
- **Dead window-closing loop removed** — `AppDelegate` no longer has a stale
  loop that manually closed windows on launch (the app has no windows).
- **Auto-hide timer energy efficiency** — the timer now uses
  `Timer.scheduledTimer` with a `tolerance` instead of a strict timer,
  reducing wake-ups on battery-powered Macs.

## [1.0.3] - 2026-06-06

### Fixed

- Fix release app signing.

## [1.0.1] - 2026-06-06

### Fixed

- Fix launch auto-hide behavior.

## [1.0.0] - 2026-06-06

### Added

- Initial release.
- Single-click toggle to hide/show menu bar icons.
- Right-click menu with Preferences and Quit.
- Auto-hide timer (2–60 seconds).
- Launch at login via `SMAppService`.
- Ultrawide monitor support.
- Multi-monitor aware.
- Position persistence via `autosaveName`.
- Menu-bar only (`LSUIElement = true`).
