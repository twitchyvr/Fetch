import Foundation

struct FormatOption: Identifiable, Hashable, Sendable {
    let id: String
    let ext: String
    let resolution: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let tbr: Double?
    let vbr: Double?
    let abr: Double?
    let note: String?

    var isVideoOnly: Bool { (acodec == "none" || acodec == nil) && vcodec != nil && vcodec != "none" }
    var isAudioOnly: Bool { (vcodec == "none" || vcodec == nil) && (acodec != nil && acodec != "none") || resolution == "audio only" }
    var hasVideo: Bool { vcodec != nil && vcodec != "none" }
    var hasAudio: Bool { acodec != nil && acodec != "none" }

    var displayName: String {
        var parts: [String] = []

        if let resolution, resolution != "audio only" {
            parts.append(resolution)
        } else if isAudioOnly {
            parts.append("Audio")
        }

        parts.append(ext.uppercased())

        if let fps, fps > 30 {
            parts.append("\(Int(fps))fps")
        }

        if let note, !note.isEmpty {
            parts.append("(\(note))")
        }

        return parts.joined(separator: " ")
    }

    var displaySize: String? {
        let size = filesize ?? filesizeApprox
        guard let size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var displayBitrate: String? {
        guard let tbr else { return nil }
        if tbr > 1000 {
            return String(format: "%.1f Mbps", tbr / 1000)
        }
        return String(format: "%.0f kbps", tbr)
    }

    init(json: [String: Any]) {
        self.id = json["format_id"] as? String ?? UUID().uuidString
        self.ext = json["ext"] as? String ?? "unknown"
        self.resolution = json["resolution"] as? String
        self.width = json["width"] as? Int
        self.height = json["height"] as? Int
        self.fps = json["fps"] as? Double
        self.vcodec = json["vcodec"] as? String
        self.acodec = json["acodec"] as? String
        self.filesize = json["filesize"] as? Int64
        self.filesizeApprox = json["filesize_approx"] as? Int64
        self.tbr = json["tbr"] as? Double
        self.vbr = json["vbr"] as? Double
        self.abr = json["abr"] as? Double
        self.note = json["format_note"] as? String
    }
}

struct MediaInfo: Sendable {
    let title: String
    let uploader: String?
    let duration: TimeInterval?
    let thumbnailURL: URL?
    let description: String?
    let formats: [FormatOption]
    let url: String
    let extractor: String
    let uploadDate: String?
    let viewCount: Int?
    let likeCount: Int?

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

    var videoFormats: [FormatOption] {
        formats.filter { $0.hasVideo && $0.hasAudio }
            .sorted { ($0.height ?? 0) > ($1.height ?? 0) }
    }

    var videoOnlyFormats: [FormatOption] {
        formats.filter { $0.isVideoOnly }
            .sorted { ($0.height ?? 0) > ($1.height ?? 0) }
    }

    var audioOnlyFormats: [FormatOption] {
        formats.filter { $0.isAudioOnly }
            .sorted { ($0.abr ?? $0.tbr ?? 0) > ($1.abr ?? $1.tbr ?? 0) }
    }

    init(json: [String: Any], url: String) {
        self.title = json["title"] as? String ?? "Unknown"
        self.uploader = json["uploader"] as? String ?? json["channel"] as? String
        self.duration = json["duration"] as? TimeInterval
        self.thumbnailURL = (json["thumbnail"] as? String).flatMap { URL(string: $0) }
        self.description = json["description"] as? String
        self.url = url
        self.extractor = json["extractor"] as? String ?? json["extractor_key"] as? String ?? "unknown"
        self.uploadDate = json["upload_date"] as? String
        self.viewCount = json["view_count"] as? Int
        self.likeCount = json["like_count"] as? Int

        let rawFormats = (json["formats"] as? [[String: Any]]) ?? []
        self.formats = rawFormats.map { FormatOption(json: $0) }
    }
}
