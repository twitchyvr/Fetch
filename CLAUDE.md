# Fetch

Native macOS SwiftUI frontend for [yt-dlp](https://github.com/yt-dlp/yt-dlp). Wraps the CLI dynamically — never hardcodes formats, options, or site support.

## Tech Stack

- **Swift 6.3** (strict concurrency enabled)
- **SwiftUI** macOS 15+ (Sequoia), `NavigationSplitView` layout
- **SwiftData** for download history and presets
- **XcodeGen** for project generation from `project.yml`
- **Zero external Swift package dependencies** — keep it this way

## Build Commands

```bash
# Regenerate .xcodeproj after changing project.yml or adding/removing source files
xcodegen generate

# Build
xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build

# Run tests
xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test

# Build and run (debug)
xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build && open ./build/Build/Products/Debug/Fetch.app
```

## Architecture

```
Fetch/
├── FetchApp.swift                  @main entry, WindowGroup + MenuBarExtra + Settings
├── Models/
│   ├── Download.swift              SwiftData @Model — persisted download history
│   ├── Preset.swift                SwiftData @Model — saved download presets
│   └── FormatOption.swift          Value types: FormatOption, MediaInfo, PlaylistInfo
├── Services/
│   ├── YTDLPService.swift          Actor — all yt-dlp process execution
│   ├── FfmpegService.swift         Actor — ffprobe analysis + ffmpeg processing
│   ├── DownloadManager.swift       @Observable @MainActor — download queue, drives UI
│   ├── ClipboardMonitor.swift      @Observable @MainActor — NSPasteboard URL detection
│   ├── NotificationService.swift   UNUserNotificationCenter + Dock badge
│   ├── SpotlightService.swift      CoreSpotlight indexing of downloads
│   ├── URLParser.swift             Multi-format URL extraction + validation
│   ├── TextAnalysisService.swift   NaturalLanguage — keywords, sentiment, insights
│   └── AppIntentsProvider.swift    Siri Shortcuts integration
└── Views/
    ├── ContentView.swift           Root NavigationSplitView + ClipboardBanner + SidebarSection enum
    ├── SidebarView.swift           Sidebar nav + yt-dlp version footer
    ├── NewDownloadView.swift       URL input → fetch info → format picker → download
    ├── DownloadQueueView.swift     Active download list + context menus
    ├── DownloadRowView.swift       Single download row with progress bar
    ├── FormatPickerView.swift      Full format table (sheet) with filters
    ├── PlaylistPickerView.swift    Playlist entry picker with 5 download modes
    ├── TranscriptOptionsView.swift Subtitle language/format picker
    ├── AdvancedOptionsView.swift   Post-processing, network, auth, output options
    ├── HistoryView.swift           SwiftData query of past downloads
    ├── LibraryView.swift           Catalog with sort/filter/search, list+grid views
    ├── StatsView.swift             Swift Charts — extractor, format, timeline
    ├── FfmpegLabView.swift         8-panel post-processing lab
    ├── PresetEditorView.swift      Preset list + detail editor (HSplitView)
    ├── SettingsView.swift          App settings (TabView: General, Downloads, Advanced)
    ├── OnboardingView.swift        4-step interactive walkthrough
    ├── DesignSystem.swift          Apple design tokens — colors, spacing, elevation
    ├── AuroraView.swift            Animated gradients + shimmer + pulsing glow
    └── TipBanner.swift             Rotating contextual tips for empty states
```

## Key Patterns — READ BEFORE CODING

### Concurrency Model

- `YTDLPService` is an **actor**. All methods are `async`. Call with `await`.
- `DownloadManager` is `@Observable @MainActor`. It's the bridge between the actor and SwiftUI.
- `DownloadTask` is `@Observable @unchecked Sendable` — transient in-memory state during a download.
- `Download` (@Model) is persisted to SwiftData only after completion.
- Use `LockedValue<T>` (bottom of YTDLPService.swift) for any mutable state captured by `Process` I/O closures. Never use bare `var` in `readabilityHandler` or `terminationHandler` closures.

### yt-dlp Integration (the core value prop)

- **Format discovery:** `yt-dlp --dump-json --no-download <url>` returns all formats per-URL. Parsed into `MediaInfo` + `[FormatOption]`.
- **Progress tracking:** `--progress-template` with tab-separated fields, parsed line-by-line via `streamProcess()`.
- **Option discovery:** `yt-dlp --help` parsed at launch into `[OptionCategory]` for dynamic settings UI.
- **Extractor list:** `yt-dlp --list-extractors` for supported sites.
- **Binary discovery:** Checks PATH via `which`, then falls back to `/opt/homebrew/bin/yt-dlp`, `/usr/local/bin/yt-dlp`.
- **Never hardcode** format IDs, resolutions, site names, or CLI flags. Always discover at runtime.

### Adding a New View

1. Create `Fetch/Views/MyNewView.swift`
2. Add a case to `SidebarSection` enum in `ContentView.swift`
3. Add the case to the `switch` in `ContentView.body`
4. Run `xcodegen generate` to update the .xcodeproj

### Adding a New Model

1. Create `Fetch/Models/MyModel.swift` with `@Model`
2. Add it to the `modelContainer(for:)` call in `FetchApp.swift`
3. Run `xcodegen generate`

### SwiftData Gotchas

- `@Model` classes are NOT `Sendable`. Don't pass them across actor boundaries.
- Store raw types (String, Int, Date) in models, not enums — use computed properties for enum wrappers (see `Download.downloadStatus`).
- `@Query` only works in SwiftUI views, not in services.

## Project Generation

This project uses **XcodeGen** (`project.yml` → `Fetch.xcodeproj`). The `.xcodeproj` is committed to git for GitHub Desktop compatibility, but `project.yml` is the source of truth.

**When to regenerate:** After adding/removing/moving Swift files, changing build settings, or adding targets. Run `xcodegen generate`.

**Do NOT** edit `Fetch.xcodeproj/project.pbxproj` by hand. Edit `project.yml` instead.

## Runtime Dependencies

- `yt-dlp` — discovered at runtime, not bundled. Install: `brew install yt-dlp`
- `ffmpeg` — optional but recommended for format merging. Install: `brew install ffmpeg`

## Git Workflow

**Local-first.** Commit directly to `main`. Push to `origin` only when explicitly needed.

- Default (and only) branch: `main`. No `feat/*` or `fix/*` branches by default — they add overhead with no payoff for a single-developer project.
- No CI/CD reliance. The repo has no `.github/workflows/`, no Issue templates, no PR template — verification happens locally.
- No GitHub Issue tracking for this project. Track work in-conversation or via TodoWrite, not `gh issue`.
- Commit style: Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).
- Co-Author trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Pre-flight before any change: `git status` clean, confirmed on `main`. After change: build, test, dogfood, commit.
- Use git worktrees for parallel work when independent tasks can run concurrently. Worktrees are local and don't conflict with this workflow.
- Push to `origin` only when explicitly requested. Never auto-push.
