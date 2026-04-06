Build the Fetch project and report results.

1. Run `xcodegen generate` to ensure the Xcode project is in sync with project.yml
2. Run `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1`
3. Report: success/failure, any warnings, any errors with file:line references
4. If there are errors, read the affected files and fix them, then rebuild
