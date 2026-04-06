# Changelog

All notable changes to Fetch are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- **Stats dashboard** — Swift Charts with bar (extractor), pie (format), line (timeline) charts
- **Interactive onboarding** — 4-step walkthrough on first launch with Skip option
- **Rotating tip banners** — contextual tips in empty queue state
- **Batch URL support** — multi-line input, JSON/CSV parsing, file drop, smart URL extraction
- **Advanced options panel** — subtitles, SponsorBlock, cookies, speed limit, output template
- **AI-friendly suggestions** — contextual tips (Whisper, podcast AI, auto-subs, SponsorBlock)
- **Thumbnail previews** — in download queue and history rows
- **File tracking** — history detects when downloaded files are deleted/moved
- **Pulsing glow indicator** — animated dot for active downloads
- Shimmer gradient effect on download progress bars
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
