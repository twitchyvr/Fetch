#!/bin/bash
# package-dmg.sh — packages a signed Release build into a signed DMG
#
# Output: ./release-build/Fetch-vX.Y.Z-macOS.dmg
#
# Usage: ./scripts/package-dmg.sh [version]
#   version defaults to MARKETING_VERSION from Info.plist
#
# Requirements:
#   - ./release-build/Release/Fetch.app must exist (run build-release.sh first)
#   - "Developer ID Application: Matthew Rogers (69LXV4BEHY)" certificate

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CERT="Developer ID Application: Matthew Rogers (69LXV4BEHY)"
APP_PATH="release-build/Release/Fetch.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found. Run scripts/build-release.sh first."
    exit 1
fi

VERSION="${1:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")}"
DMG_NAME="Fetch-v${VERSION}-macOS.dmg"
DMG_PATH="release-build/$DMG_NAME"
STAGING="/tmp/fetch-dmg-staging-$$"

echo "==> Building DMG for version $VERSION"

# Stage the .app + Applications symlink
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Build the DMG
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Fetch ${VERSION}" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "==> Signing DMG with timestamp"
codesign \
    --sign "$CERT" \
    --timestamp \
    "$DMG_PATH"

echo ""
echo "==> Verifying DMG signature"
codesign -dvvv "$DMG_PATH" 2>&1 | grep -E '(Authority|Identifier|Signed Time|Timestamp)'

echo ""
echo "==> DMG ready: $DMG_PATH"
ls -lh "$DMG_PATH"
echo ""
echo "    Next step: ./scripts/notarize-dmg.sh $DMG_PATH"
