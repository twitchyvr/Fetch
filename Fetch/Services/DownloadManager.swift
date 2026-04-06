import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class DownloadManager {
    private(set) var activeTasks: [DownloadTask] = []
    var activeDownloadCount: Int {
        activeTasks.filter { $0.status == .downloading || $0.status == .queued || $0.status == .postprocessing }.count
    }
    private(set) var ytdlpVersion: String?
    private(set) var updateAvailable = false
    private(set) var isCheckingVersion = false

    var maxConcurrentDownloads: Int {
        UserDefaults.standard.object(forKey: "maxConcurrentDownloads") as? Int ?? 3
    }
    var defaultOutputDirectory: String {
        UserDefaults.standard.string(forKey: "defaultOutputDirectory") ?? "~/Downloads/Fetch"
    }
    var modelContext: ModelContext?

    private let service = YTDLPService()
    private var runningCount = 0

    // MARK: - Version & Updates

    func checkVersion() async {
        isCheckingVersion = true
        defer { isCheckingVersion = false }

        do {
            let (version, hasUpdate) = try await service.checkForUpdate()
            ytdlpVersion = version
            updateAvailable = hasUpdate
        } catch {
            ytdlpVersion = nil
        }
    }

    func updateYTDLP() async throws -> String {
        let result = try await service.performUpdate()
        await checkVersion()
        return result
    }

    // MARK: - Media Info

    func fetchMediaInfo(for url: String) async throws -> MediaInfo {
        try await service.getMediaInfo(for: url)
    }

    // MARK: - Service Pass-through (for Settings)

    func findBinaryPath() async throws -> String {
        try await service.findBinary()
    }

    func listExtractors() async throws -> [String] {
        try await service.listExtractors()
    }

    func fetchPlaylistInfo(for url: String) async throws -> PlaylistInfo? {
        try await service.getPlaylistInfo(for: url)
    }

    // MARK: - Download Queue

    func enqueue(
        url: String,
        title: String,
        formatId: String?,
        formatDescription: String? = nil,
        preset: Preset? = nil,
        additionalArgs: [String] = [],
        thumbnailURL: String? = nil,
        extractor: String? = nil,
        duration: Double? = nil,
        playlistTitle: String? = nil,
        playlistIndex: Int? = nil,
        playlistId: String? = nil,
        scheduledFor: Date? = nil
    ) {
        var combinedArgs = preset?.asArguments() ?? []
        combinedArgs += additionalArgs

        // Playlist downloads go to a subfolder
        let baseDir = preset?.outputDirectory ?? defaultOutputDirectory
        let outputDir: String
        if let playlistTitle {
            // Sanitize: strip path separators, .., control characters, and macOS-illegal chars
            let safeTitle = Self.sanitizeFilename(playlistTitle)
            let candidate = NSString(string: baseDir).appendingPathComponent(safeTitle)
            let expandedBase = NSString(string: baseDir).expandingTildeInPath
            let expandedCandidate = NSString(string: candidate).expandingTildeInPath

            // Verify the resolved path stays within the base directory
            if NSString(string: expandedCandidate).standardizingPath
                .hasPrefix(NSString(string: expandedBase).standardizingPath) {
                outputDir = candidate
            } else {
                outputDir = baseDir // Path traversal attempt — fall back to base
            }
        } else {
            outputDir = baseDir
        }

        let task = DownloadTask(
            url: url,
            title: title,
            formatId: formatId,
            formatDescription: formatDescription,
            outputDirectory: outputDir,
            outputTemplate: preset?.outputTemplate ?? "%(title)s.%(ext)s",
            extraArgs: combinedArgs,
            thumbnailURL: thumbnailURL,
            extractor: extractor,
            duration: duration,
            playlistTitle: playlistTitle,
            playlistIndex: playlistIndex,
            playlistId: playlistId,
            scheduledFor: scheduledFor
        )

        if let scheduledFor {
            // Scheduled download — set to scheduled status, start timer
            task.status = .scheduled
            activeTasks.append(task)
            let delay = max(scheduledFor.timeIntervalSinceNow, 0)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard task.status == .scheduled else { return }
                task.status = .queued
                processQueue()
                updateDockBadge()
            }
        } else {
            activeTasks.append(task)
            processQueue()
        }
        updateDockBadge()
    }

    func cancel(_ task: DownloadTask) {
        task.status = .cancelled
        task.processHandle?.terminate()
        processQueue()
        updateDockBadge()
    }

    func cancelAll() {
        for task in activeTasks where task.status == .downloading || task.status == .queued {
            task.status = .cancelled
            task.processHandle?.terminate()
        }
        updateDockBadge()
    }

    func removeCompleted() {
        activeTasks.removeAll { $0.status == .completed || $0.status == .cancelled || $0.status == .failed }
        updateDockBadge()
    }

    func retry(_ task: DownloadTask) {
        task.status = .queued
        task.progress = 0
        task.speed = nil
        task.eta = nil
        task.error = nil
        processQueue()
    }

    // MARK: - Private

    private func processQueue() {
        let downloading = activeTasks.filter { $0.status == .downloading }.count
        let available = maxConcurrentDownloads - downloading

        guard available > 0 else { return }

        let queued = activeTasks.filter { $0.status == .queued }

        for task in queued.prefix(available) {
            startDownload(task)
        }
    }

    private func startDownload(_ task: DownloadTask) {
        task.status = .downloading

        // Copy task properties to locals before crossing actor boundary
        // to avoid data race on @unchecked Sendable DownloadTask
        let taskURL = task.url
        let taskFormatId = task.formatId
        let taskOutputDir = task.outputDirectory
        let taskOutputTemplate = task.outputTemplate
        let taskExtraArgs = task.extraArgs

        Task.detached { [service, weak self] in
            do {
                // Remove format flag from extraArgs if we already have a formatId
                var extraArgs = taskExtraArgs
                if taskFormatId != nil {
                    var filtered: [String] = []
                    var skip = false
                    for arg in extraArgs {
                        if skip { skip = false; continue }
                        if arg == "-f" || arg == "--format" { skip = true; continue }
                        filtered.append(arg)
                    }
                    extraArgs = filtered
                }

                let outputPath = try await service.download(
                    url: taskURL,
                    formatId: taskFormatId,
                    outputDirectory: taskOutputDir,
                    outputTemplate: taskOutputTemplate,
                    extraArgs: extraArgs,
                    onProcessStart: { process in
                        Task { @MainActor in
                            task.processHandle = process
                        }
                    }
                ) { progress in
                    Task { @MainActor in
                        task.progress = progress.percentage
                        task.speed = progress.speed
                        task.eta = progress.eta
                        task.totalSize = progress.totalSize
                        switch progress.status {
                        case .downloading:
                            task.status = .downloading
                        case .postprocessing:
                            task.status = .postprocessing
                        case .completed:
                            task.status = .completed
                        }
                    }
                }

                await MainActor.run {
                    task.processHandle = nil
                    guard task.status != .cancelled else {
                        self?.processQueue()
                        self?.updateDockBadge()
                        return
                    }
                    task.status = .completed
                    task.outputPath = outputPath
                    task.progress = 100
                    if let context = self?.modelContext {
                        self?.saveToHistory(task, context: context)
                    }
                    self?.processQueue()
                    self?.updateDockBadge()
                    Task {
                        await NotificationService.shared.notifyDownloadComplete(
                            title: task.title ?? task.url,
                            outputPath: outputPath
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    task.processHandle = nil
                    if task.status != .cancelled {
                        task.status = .failed
                        task.error = error.localizedDescription
                    }
                    self?.processQueue()
                    self?.updateDockBadge()
                }
            }
        }
    }

    private func updateDockBadge() {
        let activeCount = activeTasks.filter {
            $0.status == .downloading || $0.status == .queued || $0.status == .postprocessing
        }.count
        NotificationService.shared.updateDockBadge(activeCount: activeCount)
    }

    // MARK: - Path Sanitization

    /// Sanitize a string for use as a directory/file name.
    /// Strips path separators, .. sequences, control chars, and macOS-illegal characters.
    static func sanitizeFilename(_ name: String) -> String {
        var safe = name
        // Remove path separators and traversal
        safe = safe.replacingOccurrences(of: "/", with: "-")
        safe = safe.replacingOccurrences(of: "\\", with: "-")
        safe = safe.replacingOccurrences(of: "..", with: "")
        // Remove macOS-illegal characters
        safe = safe.replacingOccurrences(of: ":", with: "-")
        safe = safe.replacingOccurrences(of: "\0", with: "")
        // Remove control characters
        safe = safe.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint && $0.value >= 32 }
            .map { String($0) }.joined()
        // Trim whitespace and dots (macOS doesn't like leading/trailing dots)
        safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        safe = safe.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return safe.isEmpty ? "Untitled" : safe
    }

    // MARK: - Save to History

    private var savedTaskIDs: Set<UUID> = []

    func saveToHistory(_ task: DownloadTask, context: ModelContext) {
        guard !savedTaskIDs.contains(task.id) else { return }
        savedTaskIDs.insert(task.id)

        // Get actual file size from disk
        var fileSize: Int64?
        if let path = task.outputPath {
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            fileSize = attrs?[.size] as? Int64
        }

        let download = Download(
            url: task.url,
            title: task.title ?? task.url,
            status: .completed,
            formatId: task.formatId,
            formatDescription: task.formatDescription ?? task.formatId,
            outputPath: task.outputPath,
            fileSize: fileSize,
            thumbnailURL: task.thumbnailURL,
            extractor: task.extractor,
            duration: task.duration,
            playlistTitle: task.playlistTitle,
            playlistIndex: task.playlistIndex,
            playlistId: task.playlistId
        )
        context.insert(download)
        try? context.save()

        // Index in Spotlight for macOS search
        SpotlightService.shared.indexDownload(
            title: download.title,
            url: download.url,
            outputPath: download.outputPath,
            extractor: download.extractor,
            duration: download.duration,
            thumbnailURL: download.thumbnailURL
        )
    }
}

// MARK: - DownloadTask

@Observable
final class DownloadTask: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: String
    let formatId: String?
    let formatDescription: String?
    let outputDirectory: String
    let outputTemplate: String
    let extraArgs: [String]
    let thumbnailURL: String?
    let extractor: String?
    let duration: Double?
    let playlistTitle: String?
    let playlistIndex: Int?
    let playlistId: String?
    let scheduledFor: Date?
    let dateCreated = Date()

    var title: String?
    var status: DownloadTaskStatus = .queued
    var progress: Double = 0
    var speed: String?
    var eta: String?
    var totalSize: String?
    var outputPath: String?
    var error: String?
    var processHandle: Process?

    init(
        url: String,
        title: String?,
        formatId: String?,
        formatDescription: String? = nil,
        outputDirectory: String,
        outputTemplate: String,
        extraArgs: [String],
        thumbnailURL: String? = nil,
        extractor: String? = nil,
        duration: Double? = nil,
        playlistTitle: String? = nil,
        playlistIndex: Int? = nil,
        playlistId: String? = nil,
        scheduledFor: Date? = nil
    ) {
        self.url = url
        self.title = title
        self.formatId = formatId
        self.formatDescription = formatDescription
        self.outputDirectory = outputDirectory
        self.outputTemplate = outputTemplate
        self.extraArgs = extraArgs
        self.thumbnailURL = thumbnailURL
        self.extractor = extractor
        self.duration = duration
        self.playlistTitle = playlistTitle
        self.playlistIndex = playlistIndex
        self.playlistId = playlistId
        self.scheduledFor = scheduledFor
    }

    enum DownloadTaskStatus: String {
        case scheduled, queued, downloading, postprocessing, completed, failed, cancelled

        var label: String {
            switch self {
            case .scheduled: "Scheduled"
            case .queued: "Queued"
            case .downloading: "Downloading"
            case .postprocessing: "Processing"
            case .completed: "Completed"
            case .failed: "Failed"
            case .cancelled: "Cancelled"
            }
        }

        var icon: String {
            switch self {
            case .scheduled: "calendar.badge.clock"
            case .queued: "clock"
            case .downloading: "arrow.down.circle"
            case .postprocessing: "gearshape.2"
            case .completed: "checkmark.circle.fill"
            case .failed: "xmark.circle.fill"
            case .cancelled: "minus.circle"
            }
        }
    }
}
