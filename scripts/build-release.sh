#!/bin/bash
# build-release.sh — produces a notarization-ready signed Release build of Fetch.app
#
# Output: ./release-build/Release/Fetch.app (signed, hardened, timestamped)
#
# Usage: ./scripts/build-release.sh
#
# Requirements:
#   - Xcode + xcodebuild
#   - xcodegen (brew install xcodegen)
#   - "Developer ID Application: Matthew Rogers (69LXV4BEHY)" certificate in Keychain
#
# Why each flag matters (Apple notarization service requirements):
#   - CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
#       xcodebuild defaults to injecting `com.apple.security.get-task-allow=true`
#       into the signed binary regardless of configuration. This entitlement
#       lets debuggers attach and is REJECTED by Apple's notary service.
#       Setting this to NO suppresses the injection.
#   - OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"
#       --timestamp: embeds an Apple-issued secure timestamp (required by notary)
#       --options runtime: enables hardened runtime (also required by notary)
#       Both are belt-and-suspenders even though ENABLE_HARDENED_RUNTIME=YES
#       is set in project.yml.
#   - CODE_SIGN_STYLE=Manual + CODE_SIGN_IDENTITY=...
#       Forces a specific Developer ID certificate, no automatic provisioning.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CERT="Developer ID Application: Matthew Rogers (69LXV4BEHY)"
TEAM_ID="69LXV4BEHY"
BUILD_DIR="$REPO_ROOT/release-build"

echo "==> Regenerating Xcode project from project.yml"
xcodegen generate

echo ""
echo "==> Building Release with Developer ID signing + timestamp + hardened runtime"
xcodebuild \
    -project Fetch.xcodeproj \
    -scheme Fetch \
    -configuration Release \
    -destination 'platform=macOS' \
    SYMROOT="$BUILD_DIR" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$CERT" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    clean build

APP_PATH="$BUILD_DIR/Release/Fetch.app"

echo ""
echo "==> Verifying signature"
codesign -dvvv "$APP_PATH" 2>&1 | grep -E '(Authority|Identifier|TeamIdentifier|Runtime|Timestamp|Signed Time)'

echo ""
echo "==> Checking entitlements (must NOT include get-task-allow)"
# Capture into a variable to avoid `pipefail` + `grep -q` SIGPIPE issues:
# `grep -q` exits early on match, closes the pipe, codesign gets SIGPIPE,
# pipefail propagates the non-zero exit even though grep matched correctly.
ENTITLEMENTS=$(codesign -d --entitlements - "$APP_PATH" 2>&1)
if echo "$ENTITLEMENTS" | grep -q "get-task-allow"; then
    echo "ERROR: get-task-allow entitlement is present — notarization will fail"
    echo "$ENTITLEMENTS"
    exit 1
fi
echo "OK — no get-task-allow"

echo ""
echo "==> Verifying secure timestamp"
# codesign output uses "Timestamp=" for the secure timestamp.
# "Signed Time=" appears only on ad-hoc / non-timestamped signatures.
SIG_INFO=$(codesign -dvvv "$APP_PATH" 2>&1)
if ! echo "$SIG_INFO" | grep -q "^Timestamp="; then
    echo "ERROR: secure timestamp missing — notarization will fail"
    echo "$SIG_INFO" | grep -iE "time"
    exit 1
fi
echo "OK — secure timestamp present"

echo ""
echo "==> Build complete: $APP_PATH"
echo "    Next step: ./scripts/package-dmg.sh"
