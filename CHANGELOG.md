# Changelog

All notable changes to Fetch are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Animated aurora gradient backgrounds on New Download and empty states
- Shimmer effect on download progress bars
- macOS notifications on download completion with "Show in Finder" and "Open" actions
- Dock badge showing active download count
- Drag-and-drop URL support in New Download view
- Clipboard monitoring for media URLs with inline banner
- VoiceOver accessibility labels on all interactive elements
- WCAG AA contrast compliance throughout
- Confirmation dialog before clearing download history
- Cmd+N keyboard shortcut for New Download
- Download format picker sheet with full format table
- Preset editor with built-in and custom presets
- MenuBarExtra with active download summary
- Settings window (General, Downloads, Advanced tabs)

### Fixed
- Download cancellation now actually terminates the yt-dlp process
- Pipe deadlock in shell() for large yt-dlp output (>64KB)
- Double continuation resume guard in streamProcess()
- Orphaned yt-dlp processes on app quit
- Thread pool starvation from blocking shell() calls
- ClipboardMonitor timer duplication on window re-show
- Deprecated NSApp.activate(ignoringOtherApps:) API
- "Clear Finished" button disabled logic edge case
- VoiceOver double-reading in combined accessibility containers
- History auto-saves on download completion (crash-safe with explicit save)
- Save deduplication prevents double history entries

### Changed
- Upgraded text from caption2 to caption for contrast compliance
- Replaced .tertiary with .secondary foreground styles
- Changed .ultraThinMaterial to .regularMaterial on clipboard banner
- Clipboard detection scoped to known media hosts (manual paste/drop accepts any URL)
- YTDLPService re-encapsulated with pass-through methods on DownloadManager
- Color.accentColor used instead of hardcoded .blue
- MenuBarExtra switched to .window style
- "New Preset" button moved to toolbar (macOS HIG)
- shell() refactored to fully async terminationHandler pattern

## [0.1.0] - 2026-04-06

### Added
- Initial scaffold — native macOS SwiftUI yt-dlp frontend
- NavigationSplitView layout with sidebar + detail
- New Download, Queue, History, Presets views
- YTDLPService actor with binary discovery, format parsing, progress streaming
- DownloadManager with concurrent queue, cancellation, retry
- SwiftData models for Download history and Presets
- XcodeGen project generation from project.yml
