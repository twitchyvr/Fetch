import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class DownloadManager {
    private(set) var activeTasks: [DownloadTask] = []
    private(set) var ytdlpVersion: String?
    private(set) var updateAvailable = false
    private(set) var isCheckingVersion = false

    var maxConcurrentDownloads = 3
    var defaultOutputDirectory = "~/Downloads/Fetch"
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

    // MARK: - Download Queue

    func enqueue(
        url: String,
        title: String,
        formatId: String?,
        formatDescription: String? = nil,
        preset: Preset? = nil,
        thumbnailURL: String? = nil,
        extractor: String? = nil,
        duration: Double? = nil
    ) {
        let task = DownloadTask(
            url: url,
            title: title,
            formatId: formatId,
            formatDescription: formatDescription,
            outputDirectory: preset?.outputDirectory ?? defaultOutputDirectory,
            outputTemplate: preset?.outputTemplate ?? "%(title)s.%(ext)s",
            extraArgs: preset?.asArguments() ?? [],
            thumbnailURL: thumbnailURL,
            extractor: extractor,
            duration: duration
        )

        activeTasks.append(task)
        processQueue()
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

        Task.detached { [service, weak self] in
            do {
                // Remove format flag from extraArgs if we already have a formatId
                var extraArgs = task.extraArgs
                if task.formatId != nil {
                    // Remove -f/--format from extra args to avoid conflict
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
                    url: task.url,
                    formatId: task.formatId,
                    outputDirectory: task.outputDirectory,
                    outputTemplate: task.outputTemplate,
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

    // MARK: - Save to History

    private var savedTaskIDs: Set<UUID> = []

    func saveToHistory(_ task: DownloadTask, context: ModelContext) {
        guard !savedTaskIDs.contains(task.id) else { return }
        savedTaskIDs.insert(task.id)

        let download = Download(
            url: task.url,
            title: task.title ?? task.url,
            status: .completed,
            formatId: task.formatId,
            formatDescription: task.formatDescription,
            outputPath: task.outputPath,
            thumbnailURL: task.thumbnailURL,
            extractor: task.extractor,
            duration: task.duration
        )
        context.insert(download)
        try? context.save()
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
        duration: Double? = nil
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
    }

    enum DownloadTaskStatus: String {
        case queued, downloading, postprocessing, completed, failed, cancelled

        var label: String {
            switch self {
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
