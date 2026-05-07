import Foundation
import Testing
@testable import Fetch

@Suite("yt-dlp Service")
struct YTDLPServiceTests {
    @Test("Finds yt-dlp binary")
    func findBinary() async throws {
        let service = YTDLPService()
        let path = try await service.findBinary()
        #expect(!path.isEmpty)
        #expect(path.hasSuffix("yt-dlp"))
    }

    @Test("Gets yt-dlp version")
    func getVersion() async throws {
        let service = YTDLPService()
        let version = try await service.getVersion()
        #expect(!version.isEmpty)
        #expect(version.contains("."))
    }
}

@Suite("Format Option Parsing")
struct FormatOptionTests {
    @Test("Parses video format from JSON")
    func parseVideoFormat() {
        let json: [String: Any] = [
            "format_id": "137",
            "ext": "mp4",
            "resolution": "1920x1080",
            "fps": 30.0,
            "vcodec": "avc1.640028",
            "acodec": "none",
            "filesize": Int64(123_456_789),
            "tbr": 2500.0,
            "format_note": "1080p",
        ]
        let format = FormatOption(json: json)

        #expect(format.id == "137")
        #expect(format.ext == "mp4")
        #expect(format.isVideoOnly)
        #expect(!format.isAudioOnly)
        #expect(format.hasVideo)
        #expect(format.displayName.contains("1080"))
    }

    @Test("Parses audio format from JSON")
    func parseAudioFormat() {
        let json: [String: Any] = [
            "format_id": "140",
            "ext": "m4a",
            "resolution": "audio only",
            "vcodec": "none",
            "acodec": "mp4a.40.2",
            "tbr": 128.0,
            "format_note": "medium",
        ]
        let format = FormatOption(json: json)

        #expect(format.id == "140")
        #expect(format.isAudioOnly)
        #expect(!format.hasVideo)
        #expect(format.hasAudio)
    }
}

@Suite("Option Parser")
struct OptionParserTests {
    @Test("Parses help text categories")
    func parseCategories() {
        let helpText = """
        General Options:
          -h, --help                     Print this help text
          --version                      Print program version

        Network Options:
          --proxy URL                    Use the specified HTTP/HTTPS/SOCKS proxy
        """

        let categories = OptionParser.parse(helpText: helpText)
        #expect(categories.count == 2)
        #expect(categories[0].name == "General Options")
        #expect(categories[0].options.count == 2)
        #expect(categories[1].name == "Network Options")
    }
}

@Suite("Preset")
struct PresetTests {
    @Test("Built-in presets generate valid arguments")
    func builtInPresets() {
        for preset in Preset.builtIn {
            let args = preset.asArguments()
            #expect(!args.isEmpty, "Preset '\(preset.name)' should produce arguments")
        }
    }

    @Test("Audio preset includes extract-audio flag")
    func audioPresetArgs() {
        let audioPreset = Preset.builtIn.first { $0.name.contains("MP3") }!
        let args = audioPreset.asArguments()
        #expect(args.contains("--extract-audio"))
        #expect(args.contains("mp3"))
    }
}

// MARK: - URL Parser Tests

@Suite("URL Parser")
struct URLParserTests {

    // MARK: - Plain text (one per line)

    @Test("Extracts URLs from plain text, one per line")
    func plainTextLines() {
        let input = """
        https://www.youtube.com/watch?v=dQw4w9WgXcQ
        https://vimeo.com/148751763
        https://www.twitch.tv/videos/123456789
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 3)
        #expect(urls[0].contains("youtube.com"))
        #expect(urls[1].contains("vimeo.com"))
        #expect(urls[2].contains("twitch.tv"))
    }

    @Test("Handles blank lines and whitespace between URLs")
    func blankLines() {
        let input = """

        https://youtube.com/watch?v=abc123

          https://vimeo.com/12345

        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 2)
    }

    @Test("Filters out non-URL text mixed with URLs")
    func mixedContent() {
        let input = """
        Here are some videos to download:
        - First: https://youtube.com/watch?v=video1
        - Second one is at https://youtube.com/watch?v=video2 and it's great
        Not a URL: just some text
        ftp://not-http.com/file
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 2)
        #expect(urls.allSatisfy { $0.hasPrefix("https://") })
    }

    // MARK: - JSON formats

    @Test("Extracts URLs from JSON string array")
    func jsonStringArray() {
        let input = """
        ["https://youtube.com/watch?v=a", "https://youtube.com/watch?v=b", "https://youtube.com/watch?v=c"]
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 3)
    }

    @Test("Extracts URLs from JSON object array with url key")
    func jsonObjectArray() {
        let input = """
        [{"url": "https://youtube.com/watch?v=a", "title": "Video A"}, {"url": "https://youtube.com/watch?v=b", "title": "Video B"}]
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 2)
    }

    // MARK: - Deduplication

    @Test("Deduplicates identical URLs")
    func deduplication() {
        let input = """
        https://youtube.com/watch?v=same
        https://youtube.com/watch?v=same
        https://youtube.com/watch?v=same
        https://youtube.com/watch?v=different
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 2)
    }

    @Test("Deduplicates case-insensitively")
    func caseInsensitiveDedup() {
        let input = """
        https://YouTube.com/watch?v=abc
        https://youtube.com/watch?v=abc
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 1)
    }

    // MARK: - Edge cases / error injection

    @Test("Returns empty for empty input")
    func emptyInput() {
        #expect(URLParser.extractURLs(from: "").isEmpty)
        #expect(URLParser.extractURLs(from: "   \n\n  ").isEmpty)
    }

    @Test("Rejects non-http schemes")
    func rejectsNonHTTP() {
        let input = """
        ftp://files.example.com/video.mp4
        file:///Users/test/video.mp4
        javascript:alert(1)
        mailto:user@example.com
        """
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.isEmpty)
    }

    @Test("Handles URLs with special characters and query params")
    func specialChars() {
        let input = "https://youtube.com/watch?v=abc&list=PLdef&index=5"
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 1)
        #expect(urls[0].contains("list=PLdef"))
    }

    @Test("Strips trailing punctuation from URLs in prose")
    func trailingPunctuation() {
        let input = "Check out https://youtube.com/watch?v=abc, it's great! Also see https://vimeo.com/123."
        let urls = URLParser.extractURLs(from: input)
        #expect(urls.count == 2)
        #expect(!urls[0].hasSuffix(","))
        #expect(!urls[1].hasSuffix("."))
    }

    @Test("Handles very long URL lists without crashing")
    func largeList() {
        let urls = (0..<500).map { "https://youtube.com/watch?v=video\($0)" }
        let input = urls.joined(separator: "\n")
        let parsed = URLParser.extractURLs(from: input)
        #expect(parsed.count == 500)
    }

    @Test("Handles malformed JSON gracefully")
    func malformedJSON() {
        let input = "[\"https://youtube.com/watch?v=a\", broken"
        let urls = URLParser.extractURLs(from: input)
        // Falls through to regex extraction
        #expect(urls.count == 1)
        #expect(urls[0].contains("youtube.com"))
    }

    @Test("Single URL returns one result")
    func singleURL() {
        let urls = URLParser.extractURLs(from: "https://youtu.be/f4iQVe-P_q8")
        #expect(urls.count == 1)
        #expect(urls[0] == "https://youtu.be/f4iQVe-P_q8")
    }
}

// MARK: - Text Analysis Tests

@Suite("Text Analysis")
struct TextAnalysisTests {

    @Test("Detects English language")
    func detectEnglish() {
        let lang = TextAnalysisService.detectLanguage("This is a video about programming in Swift")
        #expect(lang != nil)
        #expect(lang!.contains("English"))
    }

    @Test("Extracts keywords from descriptive text")
    func extractKeywords() {
        let text = "Apple released a new MacBook Pro with the M4 chip. The company also announced updates to Xcode and Swift programming language."
        let keywords = TextAnalysisService.extractKeywords(from: text, limit: 5)
        #expect(!keywords.isEmpty)
    }

    @Test("Analyzes positive sentiment")
    func positiveSentiment() {
        let result = TextAnalysisService.analyzeSentiment("This is absolutely amazing and wonderful! I love it so much!")
        #expect(result.label == "Positive" || result.label == "Neutral")
    }

    @Test("Analyzes negative sentiment")
    func negativeSentiment() {
        let result = TextAnalysisService.analyzeSentiment("This is terrible and awful. I hate everything about it. Worst experience ever.")
        #expect(result.label == "Negative" || result.label == "Neutral")
    }

    @Test("Summarizes text to fewer sentences")
    func summarize() {
        let text = "Swift is a powerful programming language. It was created by Apple for iOS and macOS development. Swift is fast, safe, and expressive. Many developers prefer Swift over Objective-C. The language continues to evolve with new features each year."
        let summary = TextAnalysisService.summarize(text, sentenceCount: 2)
        #expect(!summary.isEmpty)
        #expect(summary.count < text.count)
    }

    @Test("Generates insights for video content")
    func generateInsights() {
        let insights = TextAnalysisService.generateInsights(
            title: "Learn SwiftUI in 2024",
            description: "A comprehensive tutorial on building macOS and iOS applications with SwiftUI. Covers views, modifiers, state management, and advanced techniques. Perfect for beginners and intermediate developers looking to master Apple's modern UI framework.",
            uploader: "Swift Tutorial Channel"
        )
        #expect(!insights.isEmpty)
        // Should have at least language detection
        #expect(insights.contains { $0.label == "Language" })
    }

    @Test("Returns empty insights for nil description")
    func emptyInsights() {
        let insights = TextAnalysisService.generateInsights(title: "Short", description: nil, uploader: nil)
        // Should still detect language from title
        let hasLang = insights.contains { $0.label == "Language" }
        #expect(hasLang || insights.isEmpty) // Either detects or returns empty — both valid
    }
}

// MARK: - Security Tests

@Suite("Security")
struct SecurityTests {

    @Test("Dangerous yt-dlp flags are filtered from preset args")
    func filterDangerousFlags() {
        let dangerous = ["--embed-metadata", "--exec", "rm -rf ~", "--audio-format", "mp3"]
        let filtered = Preset.filterDangerousFlags(dangerous)
        #expect(!filtered.contains("--exec"))
        #expect(!filtered.contains("rm -rf ~"))
        #expect(filtered.contains("--embed-metadata"))
        #expect(filtered.contains("--audio-format"))
        #expect(filtered.contains("mp3"))
    }

    @Test("--exec-before-download is also filtered")
    func filterExecBefore() {
        let args = ["--exec-before-download", "curl evil.com", "--format", "best"]
        let filtered = Preset.filterDangerousFlags(args)
        #expect(!filtered.contains("--exec-before-download"))
        #expect(!filtered.contains("curl evil.com"))
        #expect(filtered.contains("--format"))
        #expect(filtered.contains("best"))
    }

    @Test("--batch-file and --config-locations are filtered")
    func filterBatchAndConfig() {
        let args = ["--batch-file", "/tmp/evil.txt", "--config-locations", "/tmp/evil.conf", "-f", "best"]
        let filtered = Preset.filterDangerousFlags(args)
        #expect(!filtered.contains("--batch-file"))
        #expect(!filtered.contains("--config-locations"))
        #expect(filtered.contains("-f"))
    }

    @Test("Safe args pass through untouched")
    func safeArgsPassthrough() {
        let args = ["--embed-thumbnail", "--embed-metadata", "-f", "bestvideo+bestaudio", "--write-subs"]
        let filtered = Preset.filterDangerousFlags(args)
        #expect(filtered == args)
    }

    @Test("Path sanitization strips traversal sequences")
    @MainActor func sanitizePathTraversal() {
        let safe = DownloadManager.sanitizeFilename("../../etc/passwd")
        #expect(!safe.contains(".."))
        #expect(!safe.contains("/"))
    }

    @Test("Path sanitization strips null bytes and control chars")
    @MainActor func sanitizeNullBytes() {
        let safe = DownloadManager.sanitizeFilename("video\0name\twith\ncontrol")
        #expect(!safe.contains("\0"))
    }

    @Test("Path sanitization returns Untitled for empty result")
    @MainActor func sanitizeEmpty() {
        let safe = DownloadManager.sanitizeFilename("...")
        #expect(safe == "Untitled")
    }

    @Test("URLParser rejects non-http schemes")
    func urlParserSchemes() {
        let urls = URLParser.extractURLs(from: "file:///etc/passwd\njavascript:alert(1)\ndata:text/html,<h1>hi</h1>")
        #expect(urls.isEmpty)
    }

    // MARK: - Error message sanitization (must never leak internal details)

    @Test("YTDLPError sanitizer does not leak absolute file paths")
    func sanitizerDropsPaths() {
        let stderr = "ERROR: Cookies file /Users/mattrogers/Library/Cookies/secret.txt could not be loaded"
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(!safe.contains("/Users/mattrogers"))
        #expect(!safe.contains("secret.txt"))
        #expect(!safe.contains("/Library/Cookies"))
    }

    @Test("YTDLPError sanitizer does not leak hostnames or HTTP details")
    func sanitizerDropsHostnames() {
        let stderr = "ERROR: [generic] Unable to download webpage: HTTPSConnection(host='private-server.internal.example.com', port=443): Failed to resolve"
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(!safe.contains("private-server.internal.example.com"))
        #expect(!safe.contains("HTTPSConnection"))
        #expect(!safe.contains("[generic]"))
    }

    @Test("YTDLPError sanitizer does not leak Python tracebacks")
    func sanitizerDropsTracebacks() {
        let stderr = """
        Traceback (most recent call last):
          File "/opt/homebrew/lib/python3.12/site-packages/yt_dlp/extractor/youtube.py", line 1234, in _extract
            raise ExtractorError("internal: foo")
        ExtractorError: internal: foo
        """
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(!safe.contains("Traceback"))
        #expect(!safe.contains("/opt/homebrew"))
        #expect(!safe.contains("python3.12"))
        #expect(!safe.contains("ExtractorError"))
    }

    @Test("YTDLPError sanitizer maps DNS failure to friendly message")
    func sanitizerNetworkError() {
        let stderr = "ERROR: Unable to download webpage: <urlopen error [Errno 8] nodename nor servname provided>"
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(safe.contains("internet connection"))
        #expect(!safe.contains("urlopen"))
        #expect(!safe.contains("Errno"))
    }

    @Test("YTDLPError sanitizer maps HTTP 403 to access-refused message")
    func sanitizerForbidden() {
        let stderr = "ERROR: unable to download video data: HTTP Error 403: Forbidden"
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(safe.contains("refused") || safe.contains("region-locked"))
        #expect(!safe.contains("HTTP Error 403"))
    }

    @Test("YTDLPError sanitizer maps unsupported URL to friendly message")
    func sanitizerUnsupportedURL() {
        let stderr = "ERROR: Unsupported URL: https://example.com/auth?token=abc123secret"
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(!safe.contains("token=abc123secret"))
        #expect(!safe.contains("example.com"))
        #expect(safe.contains("recognize") || safe.contains("video page"))
    }

    @Test("YTDLPError sanitizer falls back to generic message for unknown stderr")
    func sanitizerUnknownFallback() {
        // Random gibberish that matches no known pattern — must NOT echo through
        let stderr = "ERROR: weird internal yt-dlp message with /Users/secret/path and 192.168.1.5 and api_key=ABC"
        let safe = YTDLPError.sanitize(stderr: stderr)
        #expect(!safe.contains("/Users/secret/path"))
        #expect(!safe.contains("192.168.1.5"))
        #expect(!safe.contains("api_key=ABC"))
        #expect(!safe.contains("weird internal"))
    }

    @Test("YTDLPError errorDescription returns sanitized text, not raw")
    func errorDescriptionUsesSanitizer() {
        let err = YTDLPError.processError(code: 1, rawDetail: "ERROR: HTTPSConnection(host='leaky.example.com'): Failed to resolve")
        let description = err.errorDescription ?? ""
        #expect(!description.contains("leaky.example.com"))
        #expect(!description.contains("HTTPSConnection"))
    }

    @Test("YTDLPError internalDetail preserves raw stderr for logging")
    func internalDetailPreservesRaw() {
        let raw = "ERROR: HTTPSConnection(host='private.example.com'): Failed to resolve"
        let err = YTDLPError.processError(code: 1, rawDetail: raw)
        // internalDetail is meant for developer logs only, so it CAN include the raw text
        #expect(err.internalDetail?.contains(raw) == true)
    }

    @Test("FfmpegError sanitizer does not leak absolute file paths")
    func ffmpegSanitizerDropsPaths() {
        let stderr = "/Users/mattrogers/Movies/private.mkv: No such file or directory"
        let safe = FfmpegError.sanitize(stderr: stderr)
        #expect(!safe.contains("/Users/mattrogers"))
        #expect(!safe.contains("private.mkv"))
        #expect(safe.contains("couldn't be found") || safe.contains("not be found"))
    }

    @Test("FfmpegError sanitizer maps invalid data to corrupt-file message")
    func ffmpegSanitizerCorrupt() {
        let stderr = "[mov,mp4,m4a,3gp,3g2,mj2 @ 0x148e042e0] moov atom not found\nInvalid data found when processing input"
        let safe = FfmpegError.sanitize(stderr: stderr)
        #expect(safe.contains("corrupt") || safe.contains("supported"))
        #expect(!safe.contains("0x148e042e0"))
        #expect(!safe.contains("moov atom"))
    }
}

@Suite("Warning Classifier")
struct WarningClassifierTests {
    @Test("Subtitle failure recognised")
    func subtitleFailure() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Some subtitles couldn't be downloaded")
        #expect(result?.category == .subtitle)
        #expect(result?.humanMessage.contains("subtitle") ?? false)
    }

    @Test("Thumbnail embed failure recognised")
    func thumbnailFailure() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Unable to embed thumbnail")
        #expect(result?.category == .thumbnail)
    }

    @Test("Format fallback chatter is ignored as noise")
    func formatFallbackIgnored() {
        let result = YTDLPError.classifyWarning(line: "Falling back to alternative format")
        #expect(result == nil)
    }

    @Test("Unknown WARNING prefix categorised as other")
    func unknownWarningIsOther() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Unknown thing happened")
        #expect(result?.category == .other)
    }

    @Test("Lines without WARNING prefix produce no warning")
    func nonWarningLineIgnored() {
        let result = YTDLPError.classifyWarning(line: "[download] 100% of 34.7MiB")
        #expect(result == nil)
    }

    @Test("Sanitised humanMessage strips absolute paths")
    func sanitiseStripsPaths() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Could not write to /Users/secret/Downloads/foo.mp4")
        #expect(result != nil)
        #expect(!(result?.humanMessage.contains("/Users/secret") ?? true))
        #expect(result?.humanMessage.contains("[path]") == true)
    }

    @Test("URL is stripped before path regex consumes its host")
    func urlStrippedBeforePath() {
        let result = YTDLPError.classifyWarning(
            line: "WARNING: Unable to fetch thumbnail from https://i.ytimg.com/vi/abc/hq720.jpg"
        )
        #expect(result?.category == .thumbnail)
        // The host+path portion of the URL must be replaced with [url], NOT [path].
        #expect(result?.humanMessage.contains("[url]") == true)
        #expect(!(result?.humanMessage.contains("ytimg") ?? true))
        #expect(!(result?.humanMessage.contains("https:[path]") ?? true))
    }
}

@Suite("Warning Types")
struct WarningTypesTests {
    @Test("Warning categories are stable raw values")
    func warningCategoryRawValues() {
        #expect(WarningCategory.subtitle.rawValue == "subtitle")
        #expect(WarningCategory.thumbnail.rawValue == "thumbnail")
        #expect(WarningCategory.postProcessing.rawValue == "postProcessing")
        #expect(WarningCategory.metadata.rawValue == "metadata")
        #expect(WarningCategory.other.rawValue == "other")
    }

    @Test("Warning struct is constructible and identifiable")
    func warningConstruction() {
        let w = Warning(category: .subtitle, humanMessage: "fr subtitle missing")
        #expect(w.category == .subtitle)
        #expect(w.humanMessage == "fr subtitle missing")
        #expect(w.timestamp <= Date())
    }

    @Test("Two warnings with the same content have different IDs")
    func warningsHaveUniqueIDs() {
        let a = Warning(category: .other, humanMessage: "x")
        let b = Warning(category: .other, humanMessage: "x")
        #expect(a.id != b.id)
    }
}
