# Fetch

A native macOS frontend for [yt-dlp](https://github.com/yt-dlp/yt-dlp), built with SwiftUI.

Fetch wraps yt-dlp with a polished native interface — paste a URL, pick a format, download. It dynamically discovers yt-dlp's capabilities at runtime, so when yt-dlp updates with new features or site support, Fetch adapts without needing a rebuild.

## Features

- **Native macOS app** — SwiftUI, feels like a first-party Apple utility
- **Dynamic format discovery** — queries yt-dlp per-URL for available formats, resolutions, and codecs
- **Download queue** — concurrent downloads with real-time progress, speed, and ETA
- **Clipboard monitoring** — detects media URLs copied to clipboard and offers one-click download
- **Download presets** — save format/quality/output configurations for different use cases
- **Download history** — SwiftData-backed history with search
- **Menu bar presence** — monitor downloads from the menu bar
- **Auto-update checking** — knows when yt-dlp has an update available
- **Option discovery** — parses `yt-dlp --help` at runtime to expose all available options
- **1800+ supported sites** — anything yt-dlp supports, Fetch supports

## Requirements

- macOS 14.0 (Sonoma) or later
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) installed via Homebrew: `brew install yt-dlp`
- [ffmpeg](https://ffmpeg.org/) recommended for format merging: `brew install ffmpeg`

## Building

Open `Fetch.xcodeproj` in Xcode 16+ and build (Cmd+B), or from the terminal:

```bash
xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build
```

## Architecture

```
Fetch/
├── Models/         SwiftData models (Download, Preset, FormatOption)
├── Services/       yt-dlp process wrapper, download manager, clipboard monitor
└── Views/          SwiftUI views (NavigationSplitView layout)
```

### Dynamic Adaptation

Fetch doesn't hardcode yt-dlp options or formats. Instead:

1. **Format detection** — `yt-dlp --dump-json <url>` returns all available formats per URL
2. **Option discovery** — `yt-dlp --help` is parsed at launch to build the settings UI
3. **Extractor list** — `yt-dlp --list-extractors` discovers supported sites
4. **Progress tracking** — `--progress-template` provides structured download progress

When yt-dlp adds a new flag, format, or site extractor, Fetch picks it up automatically.

## License

MIT
