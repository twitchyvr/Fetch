import Foundation
import SwiftData

@Model
final class Download {
    // Indexes matching actual #Predicate + sort usage:
    // - [\.status, \.dateCreated]: LibraryView filters on status=="completed" then sorts by dateCreated
    // - [\.dateCreated]: HistoryView, StatsView, FfmpegLabView all sort by dateCreated with no status filter
    // extractor/isFavorite are filtered in-memory (Swift Array.filter), not in #Predicate, so
    // indexes on them would provide zero benefit to current queries.
    #Index<Download>([\.status, \.dateCreated], [\.dateCreated])

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

    // Rich metadata (from yt-dlp --dump-json)
    var videoDescription: String?
    var uploaderName: String?
    var webpageURL: String?
    var viewCount: Int64?
    var likeCount: Int64?
    var commentCount: Int64?
    var channelURL: String?
    var tags: String?  // comma-separated for SwiftData compatibility

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
        videoDescription: String? = nil,
        uploaderName: String? = nil,
        webpageURL: String? = nil,
        viewCount: Int64? = nil,
        likeCount: Int64? = nil,
        commentCount: Int64? = nil,
        channelURL: String? = nil,
        tags: String? = nil,
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
        self.videoDescription = videoDescription
        self.uploaderName = uploaderName
        self.webpageURL = webpageURL
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.channelURL = channelURL
        self.tags = tags
        self.playlistTitle = playlistTitle
        self.playlistIndex = playlistIndex
        self.playlistId = playlistId
        self.dateCreated = Date()
    }

    /// Unit separator (U+001F) — ASCII control char that yt-dlp tags cannot contain,
    /// so joining/splitting is collision-safe even for tags that contain commas.
    static let tagSeparator: Character = "\u{1F}"

    var tagList: [String] {
        tags?.split(separator: Self.tagSeparator).map(String.init) ?? []
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
