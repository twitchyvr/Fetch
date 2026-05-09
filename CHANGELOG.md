# Changelog

All notable changes to Fetch are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.3.0] - 2026-05-08

First stable release after the `v0.2.1-beta.1` line. Notarized by Apple.

The headline change is an honest download-status model: when yt-dlp succeeds in writing a video file but exits non-zero (because a subtitle language was missing, a thumbnail couldn't be embedded, or some other non-fatal issue), Fetch no longer reports the download as `Failed`. A new amber **Completed with warnings** state distinguishes "succeeded but had a side-issue" from real failure.

### Added

- **Three-state download status** — `Completed` (green) / `Completed with warnings` (amber) / `Failed` (red). The amber state is new, replacing the previous binary success/failure model that produced false negatives.
- **Warning detail sheet** — tap any amber row in the queue to inspect the warnings, grouped by category (Subtitles, Thumbnail, Post-processing, Metadata, Other). Reveals the output folder in Finder and offers a "Copy log" action.
- **Stderr warning classifier** — yt-dlp `WARNING:` lines are categorised and sanitised (paths, URLs stripped) before reaching the UI. Known noise like format-fallback chatter is filtered out.
- **VoiceOver warning announcement** — queue, history, and library rows now read out the warning state for screen-reader users.

### Fixed

- **False-failure on completed downloads** — the headline bug. `streamProcess()` previously threw on any non-zero yt-dlp exit code, surfacing the generic *"yt-dlp couldn't process this video. Try a different URL or update yt-dlp"* error even when the video file was on disk. The success oracle now derives from three independent signals (captured filepath via `--print after_move:fetch_outpath:`, filesystem existence, classified warnings) rather than from exit code alone.
- **Library hidden records** — `LibraryView`'s SwiftData query previously filtered `status == "completed"` exactly, so any historical record with the new `completedWithWarnings` status would have been silently invisible. The query now includes both states.

### Changed

- **`streamProcess` no longer throws on non-zero exit** — it returns a `ProcessRunResult` (exit code, captured filepath, classified warnings) and the caller decides via the new `OutcomeBuilder.build(...)`. Exit code is informational, not authoritative.
- **`download()` returns `DownloadOutcome`** — sum type with cases `.completed(path)`, `.completedWithWarnings(path, warnings)`, `.failed(message)`, `.cancelled`. Replaces the previous bare `String` return.
- **Print sentinel changed** — `filepath:` → `fetch_outpath:`, anchored on `hasPrefix`, to avoid collision with arbitrary stderr text containing `filepath:`.

### Internal

- New `Fetch/Services/DownloadOutcome.swift` carries the new types (`Warning`, `WarningCategory`, `ProcessRunResult`, `DownloadOutcome`, `OutcomeBuilder`) extracted from `YTDLPService.swift`.
- `.no-auto-format` marker at repo root opts out of the global swift-format hook (which doesn't match the codebase's existing 4-space + Xcode-style alignment).
- Test count: **64 tests** in 11 suites — including a regression test (`regression_exit1FilePresentSynthesisesWarning`) that fails without the fix, and a Tier-2 integration test (`testRealYTDLPDryRun`) that spawns real yt-dlp with `--simulate`.

## [0.2.1-beta.1] - 2026-04-07

First beta of the v0.2.1 release. Code-signed with Developer ID. Not yet notarized — see #134.

### Added
- **App icon** — custom-designed squircle with the Fetch blue→purple gradient and a download arrow. The previous releases shipped without an icon
- **Video detail view** — rich metadata sheet showing description, view/like/comment counts, channel, tags, categories, share URL, and file info. Accessible from New Download media card and Library row tap (#99)
- YouTube search integration — paste search URLs, browse results (#97)

### Changed
- **Minimum macOS version raised to 15.0 (Sequoia)** — required for SwiftData 2.0 `#Index` macro (#105)

### Performance
- SwiftData indexes on `[\.status, \.dateCreated]` compound + `[\.dateCreated]` single — matches LibraryView's `#Predicate` filter-then-sort and the sort-only queries in HistoryView, StatsView, and FfmpegLabView. Eliminates table scans (#105)

### Security
- **Sanitized error messages** — yt-dlp and ffmpeg stderr no longer leak absolute file paths, cookie file paths, hostnames, auth tokens in URLs, Python tracebacks, or internal module identifiers. 15+ known patterns map to user-safe messages, unknowns fall back to a generic message, raw text preserved only on `internalDetail` for developer logs (#114)

### Fixed
- Broken `playlist-picker-view.png` references in README and landing page (#108)
- README, CLAUDE.md, and Wiki architecture trees synced to current source (9 services, 19 views, 3 models) (#108)
- Download button moved above fold — visible without scrolling (#102)
- URL scheme validation — blocks file://, javascript:// (#93)
- Dangerous yt-dlp flag deny-list — --exec, --batch-file filtered (#94)
- .tertiary contrast upgraded to .secondary (4.74:1 WCAG AA) (#89)
- .orange warning color darkened to #CC7700 (4.6:1 WCAG AA) (#90)
- Password warning when credentials in process args (#75)
- StatsView chart data cached in @State (#81)
- suggestionsForMedia deduplicated call (#82)
- processHandle nil'd after completion (#83)
- Accessibility traits on onboarding dots, FFmpeg tabs, playlist modes (#84)
- Dead code removed — unused @State vars, non-private methods (#85)
- Security test suite — 8 tests verifying all defense mechanisms

### Security
- Path traversal protection via sanitizeFilename + prefix check (#70)
- DownloadTask data race fix — property copies before actor boundary (#71)
- NLP computation moved off main thread (#72)
- FormatPickerView Cancel + Escape key (#73)
- TipBanner declarative Timer.publish (#74)

## [0.2.0] - 2026-04-06

### Added
- **Stats dashboard** — Swift Charts with bar (extractor), pie (format), line (timeline) charts
- **Interactive onboarding** — 4-step walkthrough on first launch with Skip option
- **Rotating tip banners** — contextual tips in empty queue state
- **Batch URL support** — multi-line input, JSON/CSV parsing, file drop, smart URL extraction
- **Advanced options panel** — subtitles, SponsorBlock, cookies, speed limit, output template
- **AI-friendly suggestions** — contextual tips (Whisper, podcast AI, auto-subs, SponsorBlock)
- **Thumbnail previews** — in download queue and history rows
- **File tracking** — history detects when downloaded files are deleted/moved
- **Playlist detection + picker** — auto-detect playlists, enumerate entries with thumbnails, 5 download modes (Best, Audio Only, Video Only, Transcript Only, Audio+Transcript), audio format picker, clickable duration toggle
- **FFmpeg Lab** — 8 operation panels: Remux, Audio, Video, Filters, Trim, Extract, Metadata, AI Presets. FfmpegService actor with ffprobe analysis, async processing, command preview
- **Media Library** — catalog all downloads with sort/filter/search, list+grid views, file-exists tracking, context menus
- **Transcript/subtitle support** — parse available languages from yt-dlp JSON, language picker, format (SRT/VTT/ASS), embed/separate file, auto-generated captions. Shows "N subtitle languages available"
- **AI export presets** — 5 AI-focused built-in presets: Whisper-ready WAV, Transcript Only, Audio+Transcript, Vision Frames 1fps, Music Lossless FLAC. Separate "AI & Research" section in Presets
- **Expanded advanced options** — AdvancedOptionsView with subtitles, post-processing (remux, extract audio, chapter split), network (proxy, geo bypass), authentication (cookies, username/password), output (template, speed limit, no-overwrites, write-info-json, write-thumbnail)
- **Scheduled downloads** — queue for later with date/time, .scheduled status with purple badge + countdown timer, auto-starts at scheduled time
- **Premium visual design** — blue-tinted dual-layer shadows (Stripe pattern), GradientButtonStyle (blue→purple), GradientProgressStyle (animated gradient fill), HoverLiftModifier (card elevation on hover), conservative radii
- **URL parser test suite** — 14 tests covering plain text, JSON, dedup, edge cases, 500-URL stress test
- **Pulsing glow indicator** — animated dot for active downloads
- Animated gradient progress bars (blue→purple)
- macOS notifications on download completion with "Show in Finder" and "Open" actions
- Dock badge showing active download count (only active, not completed)
- Drag-and-drop URL support (URLs + text files) in New Download view
- Clipboard monitoring for media URLs with inline banner
- VoiceOver accessibility labels on all interactive elements
- WCAG AA contrast compliance throughout
- Confirmation dialog before clearing download history
- Cmd+N keyboard shortcut for New Download
- Download format picker sheet with full format table
- Preset editor with built-in and custom presets
- MenuBarExtra with active download summary
- Settings window (General, Downloads, Advanced tabs)
- Apple design system tokens (DesignSystem.swift) — colors, spacing, radius, elevation
- Card elevation modifiers and glass-morphism backgrounds
- GitHub Pages landing page at twitchyvr.github.io/Fetch/
- Wiki with Architecture, Getting Started, yt-dlp Integration pages
- AGPL-3.0 license, CONTRIBUTING.md, issue/PR templates

### Fixed
- Download cancellation now actually terminates the yt-dlp process
- Pipe deadlock in shell() for large yt-dlp output (>64KB)
- Double continuation resume guard in streamProcess()
- Orphaned yt-dlp processes on app quit
- Thread pool starvation from blocking shell() calls
- ClipboardMonitor timer duplication on window re-show
- Settings now wired to DownloadManager (maxConcurrent, outputDirectory)
- isVideoOnly/isAudioOnly operator precedence bug fixed
- "Download Again" in History actually re-enqueues (was just copying URL)
- fetchInfo() cancels previous in-flight task before starting new
- Queue sidebar badge only counts active downloads (not completed)
- Sidebar "New Download" text no longer clips (columnWidth on correct view)
- Onboarding: Skip button, Return key advances, dismissable
- File size populated from disk in download history
- FileManager.fileExists dispatched to background thread (scroll perf)
- Accessibility: thumbnails hidden from VoiceOver, labels on all rows
- Progress overlay contrast improved for light thumbnails

### Changed
- Upgraded text from caption2 to caption for contrast compliance
- Color.accentColor used instead of hardcoded .blue throughout
- MenuBarExtra switched to .window style
- shell() refactored to fully async terminationHandler pattern
- DownloadManager.service re-encapsulated (private + pass-through methods)
- Clipboard detection scoped to known media hosts (manual paste accepts any URL)

## [0.1.0] - 2026-04-06

### Added
- Initial scaffold — native macOS SwiftUI yt-dlp frontend
- NavigationSplitView layout with sidebar + detail
- New Download, Queue, History, Presets views
- YTDLPService actor with binary discovery, format parsing, progress streaming
- DownloadManager with concurrent queue, cancellation, retry
- SwiftData models for Download history and Presets
- XcodeGen project generation from project.yml
