import Foundation

actor YTDLPService {
    private var cachedBinaryPath: String?

    // MARK: - Binary Discovery

    func findBinary() async throws -> String {
        if let cached = cachedBinaryPath { return cached }

        // Try `which` first (respects user PATH)
        if let path = try? await shell("/usr/bin/which", ["yt-dlp"]).output
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            cachedBinaryPath = path
            return path
        }

        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                cachedBinaryPath = path
                return path
            }
        }

        throw YTDLPError.binaryNotFound
    }

    func getVersion() async throws -> String {
        let bin = try await findBinary()
        return try await shell(bin, ["--version"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Media Info

    func getMediaInfo(for url: String) async throws -> MediaInfo {
        let bin = try await findBinary()
        let result = try await shell(bin, [
            "--dump-json",
            "--no-download",
            "--no-playlist",
            "--no-warnings",
            url,
        ])

        guard let data = result.output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw YTDLPError.parseError(detail: "Failed to parse media info JSON")
        }

        return MediaInfo(json: json, url: url)
    }

    // MARK: - Playlist

    /// Detect whether a URL is a playlist and enumerate its entries.
    /// Returns nil if the URL is a single video (not a playlist).
    func getPlaylistInfo(for url: String) async throws -> PlaylistInfo? {
        let bin = try await findBinary()
        let result = try await shell(bin, [
            "--flat-playlist",
            "--dump-json",
            "--no-download",
            "--no-warnings",
            url,
        ])

        // --flat-playlist --dump-json outputs one JSON object per line
        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil } // single video, not a playlist

        var entries: [PlaylistEntry] = []
        var playlistTitle: String?
        var playlistId: String?
        var playlistUploader: String?

        for (index, line) in lines.enumerated() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // Extract playlist metadata from first entry
            if index == 0 {
                playlistTitle = json["playlist_title"] as? String ?? json["playlist"] as? String
                playlistId = json["playlist_id"] as? String
                playlistUploader = json["playlist_uploader"] as? String
            }

            let entry = PlaylistEntry(
                url: json["url"] as? String ?? json["webpage_url"] as? String ?? "",
                title: json["title"] as? String ?? "Entry \(index + 1)",
                duration: json["duration"] as? TimeInterval,
                thumbnailURL: (json["thumbnail"] as? String).flatMap { URL(string: $0) },
                index: index + 1
            )
            if !entry.url.isEmpty {
                entries.append(entry)
            }
        }

        guard !entries.isEmpty else { return nil }

        return PlaylistInfo(
            title: playlistTitle ?? "Playlist",
            id: playlistId,
            uploader: playlistUploader,
            entries: entries,
            url: url
        )
    }

    // MARK: - Search

    /// Search YouTube (or other supported sites) via yt-dlp's ytsearch.
    /// Returns results as a PlaylistInfo for reuse in the playlist picker.
    func search(query: String, maxResults: Int = 20) async throws -> PlaylistInfo {
        let bin = try await findBinary()
        let searchTerm = "ytsearch\(maxResults):\(query)"
        let result = try await shell(bin, [
            "--flat-playlist",
            "--dump-json",
            "--no-download",
            "--no-warnings",
            searchTerm,
        ])

        let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var entries: [PlaylistEntry] = []

        for (index, line) in lines.enumerated() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let videoURL = json["url"] as? String ?? json["webpage_url"] as? String ?? ""
            let entry = PlaylistEntry(
                url: videoURL.hasPrefix("http") ? videoURL : "https://www.youtube.com/watch?v=\(videoURL)",
                title: json["title"] as? String ?? "Result \(index + 1)",
                duration: json["duration"] as? TimeInterval,
                thumbnailURL: (json["thumbnail"] as? String).flatMap { URL(string: $0) },
                index: index + 1
            )
            if !entry.url.isEmpty {
                entries.append(entry)
            }
        }

        return PlaylistInfo(
            title: "Search: \(query)",
            id: nil,
            uploader: nil,
            entries: entries,
            url: searchTerm
        )
    }

    /// Detect if a URL is a YouTube search results page.
    static func isSearchURL(_ url: String) -> String? {
        guard let urlObj = URL(string: url),
              let host = urlObj.host,
              (host.contains("youtube.com") || host.contains("youtu.be")),
              url.contains("search_query=")
        else { return nil }

        // Extract search query from URL
        guard let components = URLComponents(string: url),
              let queryItem = components.queryItems?.first(where: { $0.name == "search_query" }),
              let query = queryItem.value
        else { return nil }

        return query.replacingOccurrences(of: "+", with: " ")
    }

    // MARK: - Download

    func download(
        url: String,
        formatId: String?,
        outputDirectory: String,
        outputTemplate: String = "%(title)s.%(ext)s",
        extraArgs: [String] = [],
        onProcessStart: (@Sendable (Process) -> Void)? = nil,
        progressHandler: @Sendable @escaping (DownloadProgress) -> Void
    ) async throws -> String {
        let bin = try await findBinary()
        let expandedDir = NSString(string: outputDirectory).expandingTildeInPath

        // Ensure output directory exists
        try FileManager.default.createDirectory(
            atPath: expandedDir,
            withIntermediateDirectories: true
        )

        var arguments = [
            "--newline",
            "--no-colors",
            "--progress-template",
            "download:%(progress._percent_str)s\t%(progress._speed_str)s\t%(progress._eta_str)s\t%(progress._total_bytes_str)s\t%(progress.status)s",
            "--progress-template",
            "postprocess:POSTPROCESSING",
            "--print", "after_move:filepath:%(filepath)s",
            "-o", "\(expandedDir)/\(outputTemplate)",
        ]

        if let formatId, !formatId.isEmpty {
            arguments += ["-f", formatId]
        }

        arguments += extraArgs
        arguments.append(url)

        let result = LockedValue("")

        try await streamProcess(bin, arguments: arguments, onProcessStart: onProcessStart) { line in
            if line.hasPrefix("download:") {
                let raw = String(line.dropFirst("download:".count))
                let parts = raw.split(separator: "\t", omittingEmptySubsequences: false).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                if parts.count >= 5 {
                    let pctString = parts[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                    progressHandler(DownloadProgress(
                        percentage: Double(pctString) ?? 0,
                        speed: parts[1] == "N/A" ? nil : parts[1],
                        eta: parts[2] == "N/A" ? nil : parts[2],
                        totalSize: parts[3] == "N/A" ? nil : parts[3],
                        status: .downloading
                    ))
                }
            } else if line.contains("POSTPROCESSING") {
                progressHandler(DownloadProgress(
                    percentage: 100, speed: nil, eta: nil, totalSize: nil,
                    status: .postprocessing
                ))
            } else if line.hasPrefix("filepath:") {
                result.set(String(line.dropFirst("filepath:".count)))
            }
        }

        progressHandler(DownloadProgress(
            percentage: 100, speed: nil, eta: nil, totalSize: nil,
            status: .completed
        ))

        let outputFilePath = result.get()
        return outputFilePath.isEmpty ? "\(expandedDir)/unknown" : outputFilePath
    }

    // MARK: - Update

    func checkForUpdate() async throws -> (current: String, updateAvailable: Bool) {
        let current = try await getVersion()
        // Compare installed version against latest by checking yt-dlp's own update check.
        // Avoid --dry-run as it's not universally supported. Instead, just report the version
        // and let the user trigger updates manually from Settings.
        return (current, false)
    }

    func performUpdate() async throws -> String {
        let bin = try await findBinary()
        return try await shell(bin, ["--update"]).output
    }

    // MARK: - Option Discovery

    func parseHelp() async throws -> [OptionCategory] {
        let bin = try await findBinary()
        let result = try await shell(bin, ["--help"])
        return OptionParser.parse(helpText: result.output)
    }

    func listExtractors() async throws -> [String] {
        let bin = try await findBinary()
        let result = try await shell(bin, ["--list-extractors"])
        return result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - Private Helpers

    private struct ShellResult {
        let output: String
        let error: String
        let exitCode: Int32
    }

    private func shell(_ path: String, _ arguments: [String]) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Accumulate pipe data asynchronously to avoid blocking the thread pool.
            let outBuffer = LockedValue(Data())
            let errBuffer = LockedValue(Data())
            let didResume = LockedValue(false)

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outBuffer.mutate { $0.append(data) }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    errBuffer.mutate { $0.append(data) }
                }
            }

            process.terminationHandler = { proc in
                // Drain any remaining data
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let remainingOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingOut.isEmpty { outBuffer.mutate { $0.append(remainingOut) } }
                if !remainingErr.isEmpty { errBuffer.mutate { $0.append(remainingErr) } }

                let outStr = String(data: outBuffer.get(), encoding: .utf8) ?? ""
                let errStr = String(data: errBuffer.get(), encoding: .utf8) ?? ""

                guard !didResume.get() else { return }
                didResume.set(true)

                if proc.terminationStatus != 0 {
                    continuation.resume(throwing: YTDLPError.processError(
                        code: proc.terminationStatus,
                        rawDetail: errStr.isEmpty ? outStr : errStr
                    ))
                } else {
                    continuation.resume(returning: ShellResult(
                        output: outStr, error: errStr, exitCode: proc.terminationStatus
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                guard !didResume.get() else { return }
                didResume.set(true)
                continuation.resume(throwing: error)
            }
        }
    }

    private func streamProcess(
        _ path: String,
        arguments: [String],
        onProcessStart: (@Sendable (Process) -> Void)? = nil,
        lineHandler: @escaping @Sendable (String) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe // yt-dlp writes progress to stderr

            let lineBuffer = LockedValue("")
            let didResume = LockedValue(false)

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                guard let chunk = String(data: data, encoding: .utf8) else { return }

                let lines = lineBuffer.appendAndExtractLines(chunk)
                for line in lines {
                    lineHandler(line)
                }
            }

            process.terminationHandler = { proc in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = lineBuffer.get()
                if !remaining.isEmpty {
                    lineHandler(remaining)
                }
                // Guard against double-resume if process fails to launch
                guard !didResume.get() else { return }
                didResume.set(true)
                if proc.terminationStatus == 0 || proc.terminationStatus == 15 {
                    // 0 = success, 15 = SIGTERM (user-initiated cancel)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: YTDLPError.processError(
                        code: proc.terminationStatus,
                        rawDetail: "yt-dlp exited with code \(proc.terminationStatus)"
                    ))
                }
            }

            do {
                try process.run()
                onProcessStart?(process)
            } catch {
                guard !didResume.get() else { return }
                didResume.set(true)
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Supporting Types

struct DownloadProgress: Sendable {
    let percentage: Double
    let speed: String?
    let eta: String?
    let totalSize: String?
    let status: ProgressStatus

    enum ProgressStatus: String, Sendable {
        case downloading, postprocessing, completed
    }
}

struct OptionCategory: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let options: [CLIOption]
}

struct CLIOption: Identifiable, Sendable {
    let id = UUID()
    let flags: String
    let description: String
}

enum YTDLPError: LocalizedError {
    case binaryNotFound
    /// `rawDetail` is captured for internal logging only — NEVER surfaced to the UI.
    /// `errorDescription` returns a sanitized message that drops paths, hostnames,
    /// tracebacks, and any other internal details from yt-dlp stderr.
    case processError(code: Int32, rawDetail: String)
    case parseError(detail: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "yt-dlp not found. Install it via Homebrew: brew install yt-dlp"
        case .processError(_, let rawDetail):
            return Self.sanitize(stderr: rawDetail)
        case .parseError:
            return "Couldn't read information about this video. Try a different URL."
        }
    }

    /// Internal-only: the raw stderr captured from the yt-dlp process. Use only for
    /// developer logging, never for UI display.
    var internalDetail: String? {
        switch self {
        case .binaryNotFound: return nil
        case .processError(let code, let rawDetail): return "code \(code): \(rawDetail)"
        case .parseError(let detail): return detail
        }
    }

    /// Maps known yt-dlp stderr patterns to user-safe messages. The raw stderr is
    /// NEVER returned — unmatched errors fall through to a generic message. This is
    /// a defense against leaking absolute paths, hostnames, cookie locations, auth
    /// tokens in URLs, Python tracebacks, and internal yt-dlp module identifiers.
    static func sanitize(stderr: String) -> String {
        let lower = stderr.lowercased()

        // --- Network failures ---
        if lower.contains("nodename nor servname")
            || lower.contains("could not resolve")
            || lower.contains("temporary failure in name resolution")
            || lower.contains("name or service not known") {
            return "Couldn't reach the server. Check your internet connection."
        }
        if lower.contains("connection refused")
            || lower.contains("connection timed out")
            || lower.contains("network is unreachable") {
            return "The server isn't responding. Try again in a moment."
        }
        if lower.contains("ssl") && (lower.contains("certificate") || lower.contains("handshake")) {
            return "Couldn't establish a secure connection to the server."
        }

        // --- HTTP statuses ---
        if lower.contains("http error 403") || lower.contains("forbidden") {
            return "Access was refused. The video may be region-locked or require sign-in."
        }
        if lower.contains("http error 404") {
            return "Video not found. It may have been removed."
        }
        if lower.contains("http error 429") || lower.contains("too many requests") {
            return "Rate-limited by the server. Wait a moment and try again."
        }
        if lower.contains("http error 5") {
            return "The server returned an error. Try again later."
        }

        // --- Common yt-dlp messages ---
        if lower.contains("video unavailable") || lower.contains("video has been removed") {
            return "This video is no longer available."
        }
        if lower.contains("private video") || lower.contains("members-only")
            || lower.contains("members only") {
            return "This video is private or members-only."
        }
        if lower.contains("age") && (lower.contains("restricted") || lower.contains("confirm")) {
            return "This video is age-restricted. Sign-in cookies may be required."
        }
        if lower.contains("sign in") || lower.contains("login required")
            || lower.contains("requires authentication") {
            return "This video requires sign-in. Add a cookies file in Advanced Options."
        }
        if lower.contains("not available in your country")
            || lower.contains("not available in your location")
            || lower.contains("geo") && lower.contains("block") {
            return "This video isn't available in your region."
        }
        if lower.contains("unsupported url") {
            return "Fetch doesn't recognize this URL. Make sure it points to a video page."
        }
        if lower.contains("live event will begin")
            || lower.contains("premiere will begin")
            || lower.contains("upcoming") {
            return "This live stream or premiere hasn't started yet."
        }
        if lower.contains("copyright") {
            return "This video is unavailable due to copyright restrictions."
        }
        if lower.contains("postprocessing") || lower.contains("ffmpeg") {
            return "Couldn't post-process the downloaded file. Make sure FFmpeg is installed."
        }

        // --- Default: never echo raw stderr ---
        return "yt-dlp couldn't process this video. Try a different URL or update yt-dlp."
    }
}

// MARK: - Help Text Parser

enum OptionParser {
    static func parse(helpText: String) -> [OptionCategory] {
        var categories: [OptionCategory] = []
        var currentName = ""
        var currentOptions: [CLIOption] = []

        for line in helpText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !line.hasPrefix(" "), !line.hasPrefix("\t"), trimmed.hasSuffix(":"), !trimmed.isEmpty {
                if !currentName.isEmpty || !currentOptions.isEmpty {
                    categories.append(OptionCategory(name: currentName, options: currentOptions))
                }
                currentName = String(trimmed.dropLast())
                currentOptions = []
            } else if trimmed.hasPrefix("-") {
                if let separatorRange = trimmed.range(of: "  ") {
                    let flags = String(trimmed[..<separatorRange.lowerBound])
                    let desc = trimmed[separatorRange.upperBound...]
                        .trimmingCharacters(in: .whitespaces)
                    currentOptions.append(CLIOption(flags: flags, description: desc))
                } else {
                    currentOptions.append(CLIOption(flags: trimmed, description: ""))
                }
            }
        }

        if !currentName.isEmpty || !currentOptions.isEmpty {
            categories.append(OptionCategory(name: currentName, options: currentOptions))
        }

        return categories
    }
}

// MARK: - Thread-safe value container

final class LockedValue<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(_ initial: T) {
        self.value = initial
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: T) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func mutate(_ transform: (inout T) -> Void) {
        lock.lock()
        transform(&value)
        lock.unlock()
    }
}

extension LockedValue where T == String {
    func appendAndExtractLines(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        value += chunk
        var lines: [String] = []
        while let idx = value.firstIndex(of: "\n") {
            let line = String(value[value.startIndex..<idx])
            value = String(value[value.index(after: idx)...])
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}

// MARK: - Download Outcome Types

enum WarningCategory: String, Sendable, Hashable {
    case subtitle, thumbnail, postProcessing, metadata, other
}

struct Warning: Sendable, Identifiable, Hashable {
    let id: UUID
    let category: WarningCategory
    let humanMessage: String
    let timestamp: Date

    init(category: WarningCategory, humanMessage: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.category = category
        self.humanMessage = humanMessage
        self.timestamp = timestamp
    }
}
