import Foundation
import SwiftData

@Model
final class Preset {
    var name: String
    var formatSelection: String
    var outputTemplate: String
    var outputDirectory: String
    var embedThumbnail: Bool
    var embedSubtitles: Bool
    var embedMetadata: Bool
    var preferredQuality: String
    var extraArguments: String
    var isDefault: Bool
    var dateCreated: Date

    init(
        name: String,
        formatSelection: String = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        outputTemplate: String = "%(title)s.%(ext)s",
        outputDirectory: String = "~/Downloads",
        embedThumbnail: Bool = true,
        embedSubtitles: Bool = false,
        embedMetadata: Bool = true,
        preferredQuality: String = "best",
        extraArguments: String = "",
        isDefault: Bool = false
    ) {
        self.name = name
        self.formatSelection = formatSelection
        self.outputTemplate = outputTemplate
        self.outputDirectory = outputDirectory
        self.embedThumbnail = embedThumbnail
        self.embedSubtitles = embedSubtitles
        self.embedMetadata = embedMetadata
        self.preferredQuality = preferredQuality
        self.extraArguments = extraArguments
        self.isDefault = isDefault
        self.dateCreated = Date()
    }

    func asArguments() -> [String] {
        var args: [String] = []

        if !formatSelection.isEmpty {
            args += ["-f", formatSelection]
        }

        if embedThumbnail {
            args += ["--embed-thumbnail"]
        }

        if embedSubtitles {
            args += ["--embed-subs"]
        }

        if embedMetadata {
            args += ["--embed-metadata"]
        }

        if !extraArguments.isEmpty {
            let parsed = extraArguments.split(separator: " ").map(String.init)
            args += Self.filterDangerousFlags(parsed)
        }

        return args
    }

    /// Deny-list yt-dlp flags that can execute arbitrary commands or access arbitrary files.
    static func filterDangerousFlags(_ args: [String]) -> [String] {
        let dangerous: Set<String> = [
            "--exec", "--exec-before-download",
            "--batch-file", "--config-locations",
            "--plugin-dirs",
        ]
        var filtered: [String] = []
        var skipNext = false
        for arg in args {
            if skipNext { skipNext = false; continue }
            if dangerous.contains(arg) {
                skipNext = true // skip the flag AND its value
                continue
            }
            filtered.append(arg)
        }
        return filtered
    }

    static var builtIn: [Preset] {
        [
            Preset(name: "Best Quality", formatSelection: "bestvideo+bestaudio/best", preferredQuality: "best"),
            Preset(name: "1080p MP4", formatSelection: "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]", preferredQuality: "1080p"),
            Preset(name: "720p MP4", formatSelection: "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720]", preferredQuality: "720p"),
            Preset(name: "Audio Only (MP3)", formatSelection: "bestaudio", preferredQuality: "audio", extraArguments: "--extract-audio --audio-format mp3 --audio-quality 0"),
            Preset(name: "Audio Only (M4A)", formatSelection: "bestaudio[ext=m4a]/bestaudio", preferredQuality: "audio", extraArguments: "--extract-audio --audio-format m4a"),
            Preset(name: "Podcast", formatSelection: "bestaudio", preferredQuality: "audio", extraArguments: "--extract-audio --audio-format mp3 --audio-quality 5 --embed-thumbnail --embed-metadata"),
        ]
    }

    static var aiBuiltIn: [Preset] {
        [
            Preset(name: "AI: Speech-to-Text (Whisper)", formatSelection: "bestaudio", preferredQuality: "audio",
                   extraArguments: "--extract-audio --audio-format wav --postprocessor-args \"ffmpeg:-ar 16000 -ac 1\""),
            Preset(name: "AI: Transcript Only", formatSelection: "bestaudio", preferredQuality: "audio",
                   extraArguments: "--write-auto-subs --sub-format vtt --skip-download --sub-langs en.*,en"),
            Preset(name: "AI: Audio + Transcript", formatSelection: "bestaudio", preferredQuality: "audio",
                   extraArguments: "--extract-audio --audio-format mp3 --audio-quality 0 --write-auto-subs --sub-format vtt --sub-langs en.*,en"),
            Preset(name: "AI: Vision Frames (1fps)", formatSelection: "bestvideo[height<=1080]", preferredQuality: "1080p",
                   extraArguments: "--postprocessor-args \"ffmpeg:-vf fps=1\" --write-thumbnail"),
            Preset(name: "AI: Music Lossless (FLAC)", formatSelection: "bestaudio", preferredQuality: "audio",
                   extraArguments: "--extract-audio --audio-format flac"),
        ]
    }
}
