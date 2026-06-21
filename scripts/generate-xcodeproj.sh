#!/bin/bash
#
# Regenerate the Xcode project from project.yml using XcodeGen.
#
# Usage:
#   scripts/generate-xcodeproj.sh
#
# Requires XcodeGen: brew install xcodegen
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is not installed." >&2
    echo "       Install it with: brew install xcodegen" >&2
    exit 1
fi

echo "==> Generating hiddenapp.xcodeproj from project.yml"
xcodegen generate

echo "==> Done. Open hiddenapp.xcodeproj in Xcode."
