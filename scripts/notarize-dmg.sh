#!/bin/bash
# notarize-dmg.sh — submits a signed DMG to Apple's notary service, waits, staples, verifies
#
# Usage: ./scripts/notarize-dmg.sh path/to/Fetch.dmg
#
# Requirements:
#   - "fetch-notary" keychain profile (one-time setup):
#       xcrun notarytool store-credentials "fetch-notary" \
#           --apple-id "your-apple-id@example.com" \
#           --team-id "69LXV4BEHY"
#   - DMG must be signed with Developer ID + secure timestamp + hardened runtime
#     (use scripts/build-release.sh + scripts/package-dmg.sh)
#
# What this does:
#   1. Submit DMG to Apple notary service (--wait blocks until result)
#   2. If accepted, staple the notarization ticket to the DMG so it works offline
#   3. Verify the staple worked
#   4. Verify Gatekeeper accepts it via spctl

set -euo pipefail

DMG="${1:?usage: notarize-dmg.sh path/to/Fetch.dmg}"
PROFILE="fetch-notary"

if [ ! -f "$DMG" ]; then
    echo "ERROR: $DMG not found"
    exit 1
fi

echo "==> Submitting $DMG to Apple notary service (this takes 5-15 minutes)"
SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG" \
    --keychain-profile "$PROFILE" \
    --wait 2>&1)
echo "$SUBMIT_OUTPUT"

# Extract status from output
STATUS=$(echo "$SUBMIT_OUTPUT" | grep -E "^\s*status:" | tail -1 | awk '{print $2}')
SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep -E "^\s*id:" | head -1 | awk '{print $2}')

if [ "$STATUS" != "Accepted" ]; then
    echo ""
    echo "ERROR: notarization status is '$STATUS' (expected 'Accepted')"
    echo ""
    echo "==> Fetching notarization log for diagnosis"
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$PROFILE"
    exit 1
fi

echo ""
echo "==> Stapling notarization ticket to DMG"
xcrun stapler staple "$DMG"

echo ""
echo "==> Validating staple"
xcrun stapler validate "$DMG"

echo ""
echo "==> Verifying with Gatekeeper (spctl)"
spctl -a -t open --context context:primary-signature -v "$DMG"

echo ""
echo "==> Notarized DMG ready: $DMG"
ls -lh "$DMG"
