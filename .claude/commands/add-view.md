Add a new view to the Fetch app.

Arguments: $ARGUMENTS (the name and purpose of the new view)

1. Create the SwiftUI view file at `Fetch/Views/<Name>View.swift`
2. Add a case to the `SidebarSection` enum in `Fetch/Views/ContentView.swift` if it should appear in the sidebar
3. Wire it into the `switch` statement in `ContentView.body`
4. Run `xcodegen generate` to update the Xcode project
5. Run a build to verify it compiles: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD)"`
6. Fix any errors and rebuild until clean
