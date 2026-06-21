# Contributing to HiddenApp

Thanks for your interest in contributing to HiddenApp! This document covers building, testing, and submitting changes.

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26.4 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting started

1. Clone the repository:
   ```bash
   git clone https://github.com/lucataco/hiddenapp.git
   cd hiddenapp
   ```

2. Generate the Xcode project:
   ```bash
   ./scripts/generate-xcodeproj.sh
   ```

3. Open in Xcode:
   ```bash
   open hiddenapp.xcodeproj
   ```

4. Select the **hiddenapp** scheme and run (Cmd+R).

## Building

```bash
./scripts/generate-xcodeproj.sh
xcodebuild -project hiddenapp.xcodeproj -scheme hiddenapp \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Testing

```bash
xcodebuild -project hiddenapp.xcodeproj -scheme hiddenapp \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO test
```

Tests live in `hiddenappTests/` and use the [Swift Testing](https://developer.apple.com/documentation/testing) framework.

## Project structure

The Xcode project is generated from `project.yml` via XcodeGen. **Do not edit `hiddenapp.xcodeproj` directly** — it is gitignored. Instead:

1. Edit `project.yml`
2. Run `./scripts/generate-xcodeproj.sh`
3. Commit `project.yml` (the `.xcodeproj` is not tracked)

## Code style

- Follow the existing Swift style in the codebase.
- Use `Logger` (from `os`) for diagnostic logging — never `print`.
- Wrap user-facing strings in `String(localized:)` or `LocalizedStringKey`.
- Add tests for new model-layer logic (Preferences, AutoHideManager, etc.).
- Keep functions short and focused; prefer small, testable units.

## Submitting changes

1. Create a feature branch from `main`.
2. Make your changes, keeping commits focused.
3. Ensure the project builds and all tests pass:
   ```bash
   ./scripts/generate-xcodeproj.sh
   xcodebuild -project hiddenapp.xcodeproj -scheme hiddenapp \
     -configuration Debug -destination 'platform=macOS' \
     CODE_SIGNING_ALLOWED=NO test
   ```
4. Open a pull request with a clear description of what changed and why.

## Releasing

Releases are triggered by pushing a `v*` tag (e.g., `v1.1.0`). The GitHub Actions `release` workflow:

1. Builds the Release configuration with Developer ID Application signing.
2. Notarizes the app via `notarytool` with an App Store Connect API key.
3. Staples the notarization ticket.
4. Creates a GitHub release with the signed zip.
5. Updates the Homebrew tap at `lucataco/homebrew-tap` with the new version and SHA256.

The version is read from `MARKETING_VERSION` in `project.yml`. Update it there before tagging.
