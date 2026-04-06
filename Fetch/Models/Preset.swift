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
            args += extraArguments.split(separator: " ").map(String.init)
        }

        return args
    }

    static let builtIn: [Preset] = [
        Preset(name: "Best Quality", formatSelection: "bestvideo+bestaudio/best", preferredQuality: "best"),
        Preset(name: "1080p MP4", formatSelection: "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]", preferredQuality: "1080p"),
        Preset(name: "720p MP4", formatSelection: "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720]", preferredQuality: "720p"),
        Preset(name: "Audio Only (MP3)", formatSelection: "bestaudio", extraArguments: "--extract-audio --audio-format mp3 --audio-quality 0", preferredQuality: "audio"),
        Preset(name: "Audio Only (M4A)", formatSelection: "bestaudio[ext=m4a]/bestaudio", extraArguments: "--extract-audio --audio-format m4a", preferredQuality: "audio"),
        Preset(name: "Podcast", formatSelection: "bestaudio", extraArguments: "--extract-audio --audio-format mp3 --audio-quality 5 --embed-thumbnail --embed-metadata", preferredQuality: "audio"),
    ]
}
