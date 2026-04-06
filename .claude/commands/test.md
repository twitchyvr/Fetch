Run the Fetch test suite and report results.

1. Run `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test 2>&1`
2. Parse output for test results (passed, failed, skipped)
3. If any tests fail, read the test file and the tested code, diagnose the failure, and fix it
4. Re-run tests until all pass
