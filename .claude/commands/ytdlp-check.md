Check the yt-dlp environment and report status.

1. Run `which yt-dlp` and `yt-dlp --version`
2. Run `which ffmpeg` and `ffmpeg -version 2>&1 | head -1`
3. Count extractors: `yt-dlp --list-extractors 2>/dev/null | wc -l`
4. Check for updates: `yt-dlp --update-to stable@latest --dry-run 2>&1`
5. Report: binary location, version, ffmpeg availability, extractor count, update status
