import Foundation
import SwiftData

@Model
final class Download {
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
        duration: Double? = nil
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
        self.dateCreated = Date()
    }

    var downloadStatus: DownloadStatus {
        get { DownloadStatus(rawValue: status) ?? .completed }
        set { status = newValue.rawValue }
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
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
