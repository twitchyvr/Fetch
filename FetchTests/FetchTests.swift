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
