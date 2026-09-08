# Contributing to HiddenApp

Thanks for your interest in contributing to HiddenApp! This document covers building, testing, and submitting changes.

## Requirements

- macOS 15 (Sequoia) or later to run; macOS 26.4 or later with Xcode 26.4+ to build
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

1. Verifies the tag matches `MARKETING_VERSION` in `project.yml`.
2. Builds the Release configuration with Developer ID Application signing.
3. Notarizes the app via `notarytool` with an App Store Connect API key.
4. Staples the notarization ticket.
5. Creates a GitHub release with the signed zip.
6. Signs the zip with the Sparkle EdDSA key and publishes a new `appcast.xml` entry to `main` (requires the `SPARKLE_PRIVATE_KEY` secret; skipped with a warning if unset).
7. Updates the Homebrew tap at `lucataco/homebrew-tap` with the new version and SHA256.

Before tagging, update both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
in `project.yml` — Sparkle needs a higher version (and build) than the last
`appcast.xml` entry or clients won't be offered the update. The workflow
fails the appcast step if the version isn't newer.

One-time setup for updates: the EdDSA keypair is already generated. The
public key is baked into the app as `SUPublicEDKey`. Store the private key
(contents of `sparkle_private_key.txt`, base64 seed) as the
`SPARKLE_PRIVATE_KEY` repository secret, then delete the local copy. If the
private key is ever lost, Sparkle supports key rotation as long as the
Developer ID certificate stays the same — generate a new keypair, ship one
update signed with the old flow, then switch keys.
