# Contributing to Fetch

Thank you for your interest in Fetch. This project accepts contributions under strict terms.

## License

Fetch is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**. By contributing, you agree that your contributions will be licensed under the same license. This means:

- Any derivative work must also be AGPL-3.0 licensed
- You must disclose source code of any modifications
- Network use counts as distribution — if you deploy a modified version as a service, you must release the source

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/twitchyvr/Fetch/issues) first
2. Use the **Bug Report** template
3. Include: macOS version, yt-dlp version, steps to reproduce, expected vs actual behavior

### Requesting Features

1. Check [existing issues](https://github.com/twitchyvr/Fetch/issues) for duplicates
2. Use the **Feature Request** template
3. Explain the problem, not just the solution

### Code Contributions

1. **Fork** the repository
2. **Create a branch**: `feat/your-feature` or `fix/your-fix`
3. **Follow project conventions**:
   - Swift 6 strict concurrency
   - SwiftUI + SwiftData architecture
   - No external Swift package dependencies
   - Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`)
4. **Run the build**: `xcodegen generate && xcodebuild -project Fetch.xcodeproj -scheme Fetch build`
5. **Run tests**: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests test`
6. **Open a Pull Request** with:
   - Summary of changes
   - Link to the related issue
   - Test plan
   - Screenshots for UI changes

### Code Standards

- **Swift 6** with strict concurrency enabled
- **No `@unchecked Sendable`** without justification
- **Actors** for service isolation, **`@Observable @MainActor`** for UI state
- **SwiftData** for persistence — no Core Data
- **XcodeGen** (`project.yml`) is the source of truth — never edit `.pbxproj` directly
- **Zero external dependencies** — keep it that way

### What We Won't Accept

- Changes that add external Swift package dependencies
- iOS/iPadOS/watchOS targets (macOS only for now)
- Hardcoded format IDs, site names, or CLI flags (yt-dlp discovers at runtime)
- Changes without tests or that break existing tests

## CLA

By submitting a pull request, you certify that:
1. Your contribution is your original work
2. You have the right to submit it under the AGPL-3.0 license
3. You agree to the AGPL-3.0 terms for your contribution

## Code of Conduct

Be respectful. Technical disagreements are fine; personal attacks are not. Maintainers reserve the right to reject contributions for any reason.
