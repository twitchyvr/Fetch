Build and launch the Fetch app for testing.

1. Run `xcodegen generate`
2. Build: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' -configuration Debug build 2>&1`
3. If build succeeds, find the built .app and launch it: `open $(xcodebuild -project Fetch.xcodeproj -scheme Fetch -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/Fetch.app`
4. Report whether the app launched successfully
