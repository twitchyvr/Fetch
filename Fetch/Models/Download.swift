import Foundation
import SwiftData

@Model
final class Download {
    #Index<Download>([\.dateCreated], [\.extractor], [\.isFavorite])

    var url: String
    var title: String
    var status: String
    var formatId: String?
    var formatDescription: String?
    var outputPath: String?
    var fileSize: Int64?
    var thumbnailURL: String?
    var extractor: String?
    var duration: Double?
    var dateCreated: Date
    var dateCompleted: Date?
    var errorMessage: String?

    // Favorites
    var isFavorite: Bool

    // Playlist / Collection grouping
    var playlistTitle: String?
    var playlistIndex: Int?
    var playlistId: String?

    init(
        url: String,
        title: String,
        status: DownloadStatus = .completed,
        formatId: String? = nil,
        formatDescription: String? = nil,
        outputPath: String? = nil,
        fileSize: Int64? = nil,
        thumbnailURL: String? = nil,
        extractor: String? = nil,
        duration: Double? = nil,
        isFavorite: Bool = false,
        playlistTitle: String? = nil,
        playlistIndex: Int? = nil,
        playlistId: String? = nil
    ) {
        self.url = url
        self.title = title
        self.status = status.rawValue
        self.formatId = formatId
        self.formatDescription = formatDescription
        self.outputPath = outputPath
        self.fileSize = fileSize
        self.thumbnailURL = thumbnailURL
        self.extractor = extractor
        self.duration = duration
        self.isFavorite = isFavorite
        self.playlistTitle = playlistTitle
        self.playlistIndex = playlistIndex
        self.playlistId = playlistId
        self.dateCreated = Date()
    }

    var downloadStatus: DownloadStatus {
        get { DownloadStatus(rawValue: status) ?? .completed }
        set { status = newValue.rawValue }
    }

    var formattedDuration: String? {
        duration.flatMap { DurationFormatter.format($0) }
    }

    var formattedFileSize: String? {
        guard let fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

enum DownloadStatus: String, Codable, CaseIterable {
    case queued
    case downloading
    case postprocessing
    case completed
    case failed
    case cancelled
}
