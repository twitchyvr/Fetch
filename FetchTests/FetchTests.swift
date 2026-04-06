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
