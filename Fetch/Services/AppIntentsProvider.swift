import AppIntents

struct DownloadURLIntent: AppIntent {
    static let title: LocalizedStringResource = "Download URL with Fetch"
    static let description = IntentDescription("Download a video or audio URL using Fetch")

    @Parameter(title: "URL")
    var url: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post a notification so the running app can pick up the URL and enqueue it
        NotificationCenter.default.post(
            name: .init("FetchDownloadURLIntent"),
            object: nil,
            userInfo: ["url": url]
        )
        return .result()
    }
}

struct FetchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DownloadURLIntent(),
            phrases: [
                "Download \(.applicationName)",
                "Download video with \(.applicationName)",
            ],
            shortTitle: "Download URL",
            systemImageName: "arrow.down.circle"
        )
    }
}
