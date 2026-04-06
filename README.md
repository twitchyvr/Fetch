# Fetch

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-brightgreen)](https://developer.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)

A native macOS frontend for [yt-dlp](https://github.com/yt-dlp/yt-dlp), built with SwiftUI.

Fetch wraps yt-dlp with a polished native interface — paste a URL, pick a format, download. It dynamically discovers yt-dlp's capabilities at runtime, so when yt-dlp updates with new features or site support, Fetch adapts without needing a rebuild.

## Features

- **Native macOS app** — SwiftUI, Apple HIG compliant, feels like a first-party utility
- **Animated aurora UI** — subtle animated gradient backgrounds with shimmer progress bars
- **Dynamic format discovery** — queries yt-dlp per-URL for available formats, resolutions, and codecs
- **Download queue** — concurrent downloads with real-time progress, speed, and ETA
- **macOS notifications** — banner notifications on download completion with "Open" and "Show in Finder" actions
- **Dock badge** — shows active download count
- **Clipboard monitoring** — detects media URLs copied to clipboard and offers one-click download
- **Drag-and-drop** — drop URLs from any browser directly into the app
- **Download presets** — save format/quality/output configurations for different use cases
- **Download history** — SwiftData-backed history with search, persists immediately
- **Menu bar presence** — monitor downloads from the menu bar (window-style MenuBarExtra)
- **Full accessibility** — VoiceOver labels, WCAG AA contrast, keyboard navigation
- **Auto-update checking** — knows when yt-dlp has an update available
- **Option discovery** — parses `yt-dlp --help` at runtime to expose all available options
- **1800+ supported sites** — anything yt-dlp supports, Fetch supports

## Requirements

- macOS 14.0 (Sonoma) or later
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) installed via Homebrew: `brew install yt-dlp`
- [ffmpeg](https://ffmpeg.org/) recommended for format merging: `brew install ffmpeg`

## Building

Fetch uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth.

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project and build
xcodegen generate
xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build

# Run tests
xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test

# Build to a known location for testing
xcodebuild -project Fetch.xcodeproj -scheme Fetch -configuration Debug SYMROOT="$(pwd)/build" build
open ./build/Debug/Fetch.app
```

Or open `Fetch.xcodeproj` in Xcode 16+ and build (Cmd+B).

## Architecture

```text
Fetch/
├── FetchApp.swift              @main entry — WindowGroup, MenuBarExtra, Settings
├── Models/
│   ├── Download.swift          SwiftData @Model — persisted download history
│   ├── Preset.swift            SwiftData @Model — saved download presets
│   └── FormatOption.swift      Value types: FormatOption + MediaInfo
├── Services/
│   ├── YTDLPService.swift      Actor — all yt-dlp process execution
│   ├── DownloadManager.swift   @Observable @MainActor — download queue
│   ├── ClipboardMonitor.swift  @Observable @MainActor — pasteboard URL detection
│   └── NotificationService.swift  UNUserNotificationCenter + Dock badge
└── Views/
    ├── ContentView.swift       Root NavigationSplitView + clipboard banner
    ├── SidebarView.swift       Sidebar navigation + yt-dlp version footer
    ├── NewDownloadView.swift   URL input → fetch info → format picker → download
    ├── DownloadQueueView.swift Active downloads + context menus
    ├── DownloadRowView.swift   Single download row with shimmer progress
    ├── FormatPickerView.swift  Full format table (sheet) with filters
    ├── HistoryView.swift       SwiftData query of past downloads
    ├── PresetEditorView.swift  Preset list + detail editor
    ├── SettingsView.swift      App settings (General, Downloads, Advanced)
    └── AuroraView.swift        Animated gradient background + shimmer style
```

### Key Design Decisions

- **Actor isolation**: `YTDLPService` is an actor. All `Process` I/O runs off the main thread via `terminationHandler` and `readabilityHandler` — no blocking the cooperative thread pool.
- **Zero external dependencies**: No SPM packages. Everything is built with system frameworks.
- **Runtime discovery**: Never hardcodes formats, sites, or CLI flags. yt-dlp's `--dump-json`, `--help`, and `--list-extractors` are the source of truth.
- **SwiftData for persistence**: Download history and presets are stored via SwiftData with explicit `context.save()` for crash safety.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. All contributions are under AGPL-3.0.

## License

Copyright (C) 2026 Matt Rogers

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU Affero General Public License v3.0** as published by the Free Software Foundation.

This is the most restrictive widely-recognized open source license. Key implications:

- **Copyleft**: Any derivative work must also be AGPL-3.0 licensed
- **Source disclosure**: You must provide source code for any modifications
- **Network use = distribution**: If you run a modified version as a network service, you must release the source
- **Attribution required**: Derivative works must credit "Based on Fetch by Matt Rogers"

See [LICENSE](LICENSE) for full terms.
