import Foundation

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

/// Result of running a yt-dlp Process. Carries everything needed to derive a
/// DownloadOutcome — exit code is informational, not authoritative.
struct ProcessRunResult: Sendable {
    let exitCode: Int32
    let capturedFilepath: String?      // from --print after_move:fetch_outpath:%(filepath)q
    let warnings: [Warning]            // already classified + sanitised
}

/// The authoritative success/failure judgement returned by `download()`.
enum DownloadOutcome: Sendable {
    case completed(path: String)
    case completedWithWarnings(path: String, warnings: [Warning])
    case failed(message: String)       // already sanitised
    case cancelled
}

/// Pure logic — no I/O except FileManager.fileExists. Easily unit-tested.
enum OutcomeBuilder {
    static func build(
        exitCode: Int32,
        capturedFilepath: String?,
        warnings: [Warning],
        fileExistsChecker: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> DownloadOutcome {
        // Cancellation takes precedence over everything.
        if exitCode == 15 { return .cancelled }

        let filePresent = capturedFilepath.map(fileExistsChecker) ?? false

        if exitCode == 0 {
            if let path = capturedFilepath, filePresent {
                return warnings.isEmpty
                    ? .completed(path: path)
                    : .completedWithWarnings(path: path, warnings: warnings)
            }
            // Legacy fallback: older yt-dlp may not emit the print line.
            return .completed(path: capturedFilepath ?? "")
        }

        // Non-zero exit, not cancelled.
        if let path = capturedFilepath, filePresent {
            // ★ Regression-fix path: file exists despite non-zero exit.
            // Synthesise a warning so the user knows something was off,
            // but mark as completed-with-warnings, NOT failed.
            var enriched = warnings
            if enriched.isEmpty {
                enriched.append(Warning(
                    category: .other,
                    humanMessage: "yt-dlp reported errors but the file is present."
                ))
            }
            return .completedWithWarnings(path: path, warnings: enriched)
        }

        // Genuine failure.
        return .failed(message: YTDLPError.sanitize(stderr: "yt-dlp exited with code \(exitCode)"))
    }
}
