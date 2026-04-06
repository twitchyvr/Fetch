import Foundation

/// Actor for running FFmpeg operations on media files.
actor FfmpegService {
    private var cachedPath: String?

    // MARK: - Binary Discovery

    func findBinary() async throws -> String {
        if let cached = cachedPath { return cached }

        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]

        // Try which first
        if let path = try? await shell("/usr/bin/which", ["ffmpeg"]).trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            cachedPath = path
            return path
        }

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                cachedPath = path
                return path
            }
        }

        throw FfmpegError.binaryNotFound
    }

    func getVersion() async throws -> String {
        let bin = try await findBinary()
        let output = try await shell(bin, ["-version"])
        return output.components(separatedBy: .newlines).first?
            .replacingOccurrences(of: "ffmpeg version ", with: "")
            .components(separatedBy: " ").first ?? "unknown"
    }

    // MARK: - Media Probe

    /// Get detailed media info using ffprobe.
    func probe(filePath: String) async throws -> MediaProbe {
        let ffprobe = try await findFfprobe()
        let output = try await shell(ffprobe, [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            filePath,
        ])

        guard let data = output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw FfmpegError.parseError("Failed to parse ffprobe output")
        }

        return MediaProbe(json: json, filePath: filePath)
    }

    // MARK: - Process

    /// Run an FFmpeg command with progress reporting.
    func run(
        inputPath: String,
        outputPath: String,
        arguments: [String],
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws {
        let bin = try await findBinary()

        var args = ["-i", inputPath] + arguments
        args += ["-y", outputPath] // -y to overwrite

        let outputBuffer = LockedValue(Data())
        let didResume = LockedValue(false)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: bin)
            process.arguments = args

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe() // suppress stdout

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputBuffer.mutate { $0.append(data) }
                    // Parse ffmpeg progress from stderr
                    if let text = String(data: data, encoding: .utf8) {
                        for line in text.components(separatedBy: "\r") {
                            if line.contains("time=") {
                                // Extract time position for progress
                                if let range = line.range(of: "time=") {
                                    let timeStr = String(line[range.upperBound...]).prefix(11)
                                    let _ = timeStr // Progress parsing would need total duration
                                }
                            }
                        }
                    }
                }
            }

            process.terminationHandler = { proc in
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                guard !didResume.get() else { return }
                didResume.set(true)
                if proc.terminationStatus == 0 {
                    progressHandler(100)
                    continuation.resume()
                } else {
                    let errStr = String(data: outputBuffer.get(), encoding: .utf8) ?? ""
                    continuation.resume(throwing: FfmpegError.processError(
                        code: proc.terminationStatus,
                        message: errStr
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

    // MARK: - Private

    private func findFfprobe() async throws -> String {
        let ffmpegPath = try await findBinary()
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        guard FileManager.default.isExecutableFile(atPath: ffprobePath) else {
            throw FfmpegError.binaryNotFound
        }
        return ffprobePath
    }

    private func shell(_ path: String, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            let buffer = LockedValue(Data())

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { buffer.mutate { $0.append(data) } }
            }

            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                let outStr = String(data: buffer.get(), encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outStr)
                } else {
                    continuation.resume(throwing: FfmpegError.processError(
                        code: proc.terminationStatus, message: outStr
                    ))
                }
            }

            do { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }
}

// MARK: - Media Probe Result

struct MediaProbe: Sendable {
    let filePath: String
    let duration: TimeInterval?
    let fileSize: Int64?
    let formatName: String?
    let videoStreams: [StreamInfo]
    let audioStreams: [StreamInfo]
    let subtitleStreams: [StreamInfo]

    struct StreamInfo: Sendable, Identifiable {
        let id: Int
        let codecName: String
        let codecType: String // video, audio, subtitle
        let width: Int?
        let height: Int?
        let sampleRate: Int?
        let channels: Int?
        let bitrate: Int64?
        let language: String?

        var resolution: String? {
            guard let w = width, let h = height else { return nil }
            return "\(w)x\(h)"
        }
    }

    init(json: [String: Any], filePath: String) {
        self.filePath = filePath

        let format = json["format"] as? [String: Any]
        self.duration = (format?["duration"] as? String).flatMap { Double($0) }
        self.fileSize = (format?["size"] as? String).flatMap { Int64($0) }
        self.formatName = format?["format_long_name"] as? String

        let streams = (json["streams"] as? [[String: Any]]) ?? []
        var video: [StreamInfo] = []
        var audio: [StreamInfo] = []
        var subtitle: [StreamInfo] = []

        for (idx, stream) in streams.enumerated() {
            let codecType = stream["codec_type"] as? String ?? ""
            let info = StreamInfo(
                id: idx,
                codecName: stream["codec_name"] as? String ?? "unknown",
                codecType: codecType,
                width: stream["width"] as? Int,
                height: stream["height"] as? Int,
                sampleRate: (stream["sample_rate"] as? String).flatMap { Int($0) },
                channels: stream["channels"] as? Int,
                bitrate: (stream["bit_rate"] as? String).flatMap { Int64($0) },
                language: (stream["tags"] as? [String: Any])?["language"] as? String
            )

            switch codecType {
            case "video": video.append(info)
            case "audio": audio.append(info)
            case "subtitle": subtitle.append(info)
            default: break
            }
        }

        self.videoStreams = video
        self.audioStreams = audio
        self.subtitleStreams = subtitle
    }
}

// MARK: - Errors

enum FfmpegError: LocalizedError {
    case binaryNotFound
    case processError(code: Int32, message: String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            "FFmpeg not found. Install via Homebrew: brew install ffmpeg"
        case .processError(let code, let message):
            "FFmpeg error (code \(code)): \(message)"
        case .parseError(let detail):
            "Failed to parse FFmpeg output: \(detail)"
        }
    }
}
