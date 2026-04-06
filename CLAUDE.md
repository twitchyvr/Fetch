# Fetch — Project Instructions

## Project Overview
Native macOS SwiftUI frontend for yt-dlp. Dynamically wraps the yt-dlp CLI — never hardcodes formats, options, or site support.

## Tech Stack
- **Language:** Swift 6.0
- **UI:** SwiftUI (macOS 14+)
- **Persistence:** SwiftData
- **Concurrency:** Swift Concurrency (actors, async/await)
- **Project Generation:** XcodeGen (`project.yml` → `Fetch.xcodeproj`)

## Build & Run
```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Build from CLI
xcodebuild -project Fetch.xcodeproj -scheme Fetch build

# Run tests
xcodebuild -project Fetch.xcodeproj -scheme FetchTests test
```

## Architecture

### Services Layer
- `YTDLPService` — Actor wrapping the yt-dlp binary. All process execution goes through here.
- `DownloadManager` — @Observable @MainActor manager for the download queue. Uses YTDLPService.
- `ClipboardMonitor` — Polls NSPasteboard for media URLs.

### Key Patterns
- YTDLPService is an `actor` for thread safety around process execution.
- DownloadManager is `@MainActor` because it drives SwiftUI views.
- `DownloadTask` is transient (in-memory during download). `Download` is persisted (SwiftData history).
- Format discovery is per-URL via `yt-dlp --dump-json`, not hardcoded.

### Adding Views
All views go in `Fetch/Views/`. New sections need a case in `SidebarSection` enum in `ContentView.swift`.

### Dependencies
- yt-dlp must be installed on the user's system (discovered at runtime via PATH or known locations).
- No Swift package dependencies — intentionally zero external deps.
