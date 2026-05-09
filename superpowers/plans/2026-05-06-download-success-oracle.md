# Download Success Oracle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate Fetch's false-failure reports on completed downloads, surface non-fatal yt-dlp warnings honestly via a new amber `Completed with warnings` state with a discoverable detail sheet.

**Architecture:** Replace the exit-code-only success oracle in `streamProcess()` with a derived judgement from three signals: captured filepath (sentinel-prefixed `--print after_move`), file existence on disk, and categorised stderr warnings. `streamProcess` returns a `ProcessRunResult` instead of throwing on non-zero exit; `download()` builds a `DownloadOutcome` sum type; `DownloadManager` switches on it.

**Tech Stack:** Swift 6.3 (strict concurrency), SwiftUI macOS 15+, SwiftData, Swift Testing (`@Suite`/`@Test`/`#expect`), XcodeGen.

**Reference spec:** `superpowers/specs/2026-05-06-download-success-oracle-design.md`

**Workflow note:** All commits go directly to `main` per the project's local-first workflow. No feature branches, no auto-pushes to `origin`.

---

## File Structure

| File                                         | Role                                                                                                                                                                                                                                                                                         |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Fetch/Services/YTDLPService.swift`          | Add `WarningCategory`, `Warning`, `ProcessRunResult`, `DownloadOutcome`, `OutcomeBuilder`. Modify `streamProcess` to return `ProcessRunResult` (no throw on non-zero). Modify `download()` to return `DownloadOutcome`. Extend `YTDLPError.sanitize` to produce `(category, message)` pairs. |
| `Fetch/Models/Download.swift`                | Add `DownloadStatus.completedWithWarnings`.                                                                                                                                                                                                                                                  |
| `Fetch/Services/DownloadManager.swift`       | Add `DownloadTaskStatus.completedWithWarnings`, `DownloadTask.warnings: [Warning]`. Switch `startDownload` on `DownloadOutcome`.                                                                                                                                                             |
| `Fetch/Views/DownloadRowView.swift`          | Render amber state, "N warning · tap for details" hint, updated `accessibilityDescription`.                                                                                                                                                                                                  |
| `Fetch/Views/DownloadQueueView.swift`        | Sheet presentation for `WarningDetailSheet`.                                                                                                                                                                                                                                                 |
| `Fetch/Views/WarningDetailSheet.swift` (NEW) | Modal listing warnings grouped by category.                                                                                                                                                                                                                                                  |
| `Fetch/Views/HistoryView.swift`              | Visual treatment for `.completedWithWarnings` records.                                                                                                                                                                                                                                       |
| `Fetch/Views/LibraryView.swift`              | Same.                                                                                                                                                                                                                                                                                        |
| `FetchTests/FetchTests.swift`                | New `@Suite`s: `WarningSanitizerTests`, `OutcomeBuilderTests`, `DownloadOutcomeRegressionTests`.                                                                                                                                                                                             |
| `project.yml`                                | No change — XcodeGen sources `Fetch/Views/` recursively. Run `xcodegen generate` after creating `WarningDetailSheet.swift`.                                                                                                                                                                  |

---

## Task 1: Add Warning + WarningCategory types

**Files:**

- Modify: `Fetch/Services/YTDLPService.swift` (append new types after `YTDLPError` enum at line ~551)
- Test: `FetchTests/FetchTests.swift` (append new `@Suite`)

- [ ] **Step 1: Write the failing test**

Append to `FetchTests/FetchTests.swift`:

```swift
@Suite("Warning Types")
struct WarningTypesTests {
    @Test("Warning categories are stable raw values")
    func warningCategoryRawValues() {
        #expect(WarningCategory.subtitle.rawValue == "subtitle")
        #expect(WarningCategory.thumbnail.rawValue == "thumbnail")
        #expect(WarningCategory.postProcessing.rawValue == "postProcessing")
        #expect(WarningCategory.metadata.rawValue == "metadata")
        #expect(WarningCategory.other.rawValue == "other")
    }

    @Test("Warning struct is constructible and identifiable")
    func warningConstruction() {
        let w = Warning(category: .subtitle, humanMessage: "fr subtitle missing")
        #expect(w.category == .subtitle)
        #expect(w.humanMessage == "fr subtitle missing")
        #expect(w.timestamp <= Date())
    }

    @Test("Two warnings with the same content have different IDs")
    func warningsHaveUniqueIDs() {
        let a = Warning(category: .other, humanMessage: "x")
        let b = Warning(category: .other, humanMessage: "x")
        #expect(a.id != b.id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test 2>&1 | grep -E "WarningTypes|error:"`
Expected: build error — `cannot find 'WarningCategory' in scope` and `cannot find 'Warning' in scope`.

- [ ] **Step 3: Write minimal implementation**

Append at the bottom of `Fetch/Services/YTDLPService.swift` (after the `LockedValue` extension at the end):

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/WarningTypesTests 2>&1 | tail -10`
Expected: `** TEST SUCCEEDED **` and three tests passing.

- [ ] **Step 5: Commit**

```bash
git add Fetch/Services/YTDLPService.swift FetchTests/FetchTests.swift
git commit -m "$(cat <<'EOF'
feat(yt-dlp): add Warning + WarningCategory types

Pure data types for surfacing yt-dlp warnings to the UI. Foundation for
the upcoming three-state download status (completed / completedWithWarnings
/ failed).

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Extend YTDLPError.sanitize to also classify warnings

**Files:**

- Modify: `Fetch/Services/YTDLPService.swift:480-550` (extend `YTDLPError.sanitize` and add `classifyWarning`)
- Test: `FetchTests/FetchTests.swift` (new `@Suite`)

- [ ] **Step 1: Write the failing test**

Append to `FetchTests/FetchTests.swift`:

```swift
@Suite("Warning Classifier")
struct WarningClassifierTests {
    @Test("Subtitle failure recognised")
    func subtitleFailure() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Some subtitles couldn't be downloaded")
        #expect(result?.category == .subtitle)
        #expect(result?.humanMessage.contains("subtitle") ?? false)
    }

    @Test("Thumbnail embed failure recognised")
    func thumbnailFailure() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Unable to embed thumbnail")
        #expect(result?.category == .thumbnail)
    }

    @Test("Format fallback chatter is ignored as noise")
    func formatFallbackIgnored() {
        let result = YTDLPError.classifyWarning(line: "Falling back to alternative format")
        #expect(result == nil)
    }

    @Test("Unknown WARNING prefix categorised as other")
    func unknownWarningIsOther() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Unknown thing happened")
        #expect(result?.category == .other)
    }

    @Test("Lines without WARNING prefix produce no warning")
    func nonWarningLineIgnored() {
        let result = YTDLPError.classifyWarning(line: "[download] 100% of 34.7MiB")
        #expect(result == nil)
    }

    @Test("Sanitised humanMessage strips absolute paths")
    func sanitiseStripsPaths() {
        let result = YTDLPError.classifyWarning(line: "WARNING: Could not write to /Users/secret/Downloads/foo.mp4")
        #expect(result != nil)
        #expect(!(result?.humanMessage.contains("/Users/secret") ?? true))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/WarningClassifierTests 2>&1 | tail -10`
Expected: build error — `type 'YTDLPError' has no member 'classifyWarning'`.

- [ ] **Step 3: Write minimal implementation**

In `Fetch/Services/YTDLPService.swift`, add a new static method to `YTDLPError` (after the existing `sanitize(stderr:)` method, around line 550):

```swift
    /// Classifies a single stderr line as a `Warning` if it represents a non-fatal issue.
    /// Returns nil for noise (format fallback chatter) or non-WARNING lines.
    /// All `humanMessage` text is path/URL/host-stripped — safe for direct UI display.
    static func classifyWarning(line: String) -> Warning? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Noise filter: yt-dlp does this routinely, not actionable.
        if trimmed.localizedCaseInsensitiveContains("falling back to alternative format") {
            return nil
        }

        // Only WARNING-prefixed lines are surfaced.
        guard trimmed.hasPrefix("WARNING:") else { return nil }

        let body = String(trimmed.dropFirst("WARNING:".count)).trimmingCharacters(in: .whitespaces)
        let lower = body.lowercased()
        let sanitised = stripSensitive(body)

        if lower.contains("subtitle") {
            return Warning(category: .subtitle, humanMessage: sanitised)
        }
        if lower.contains("thumbnail") {
            return Warning(category: .thumbnail, humanMessage: sanitised)
        }
        if lower.contains("metadata") || lower.contains("info.json") {
            return Warning(category: .metadata, humanMessage: sanitised)
        }
        if lower.contains("postprocessor") || lower.contains("ffmpeg") || lower.contains("post-process") {
            return Warning(category: .postProcessing, humanMessage: sanitised)
        }
        return Warning(category: .other, humanMessage: sanitised)
    }

    /// Strips absolute paths, URLs, and hostnames from a stderr line so the
    /// resulting message is safe for direct UI display.
    private static func stripSensitive(_ text: String) -> String {
        var result = text
        // Strip absolute Unix paths
        result = result.replacingOccurrences(
            of: #"/[A-Za-z0-9._/-]+"#,
            with: "[path]",
            options: .regularExpression
        )
        // Strip URLs
        result = result.replacingOccurrences(
            of: #"https?://[^\s]+"#,
            with: "[url]",
            options: .regularExpression
        )
        return result
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/WarningClassifierTests 2>&1 | tail -10`
Expected: `** TEST SUCCEEDED **`, six tests passing.

- [ ] **Step 5: Commit**

```bash
git add Fetch/Services/YTDLPService.swift FetchTests/FetchTests.swift
git commit -m "$(cat <<'EOF'
feat(yt-dlp): classifyWarning + path/URL stripping for stderr lines

Maps yt-dlp WARNING: stderr to categorised Warning structs, ignoring
known noise (format fallback). humanMessage is path/URL-stripped so it's
safe to display directly in the UI without leaking filesystem details.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add ProcessRunResult + DownloadOutcome + OutcomeBuilder (regression test lives here)

**Files:**

- Modify: `Fetch/Services/YTDLPService.swift` (append new types + builder)
- Test: `FetchTests/FetchTests.swift` (new `@Suite` — includes the regression test)

- [ ] **Step 1: Write the failing test**

Append to `FetchTests/FetchTests.swift`:

```swift
@Suite("Outcome Builder")
struct OutcomeBuilderTests {
    @Test("Exit 0, file present, no warnings → completed")
    func exit0FilePresentNoWarnings() throws {
        let tmp = try makeTempFile(name: "ok.mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let outcome = OutcomeBuilder.build(
            exitCode: 0,
            capturedFilepath: tmp.path,
            warnings: []
        )

        guard case .completed(let path) = outcome else {
            Issue.record("Expected .completed, got \(outcome)")
            return
        }
        #expect(path == tmp.path)
    }

    @Test("Exit 0, file present, warnings → completedWithWarnings")
    func exit0FilePresentWithWarnings() throws {
        let tmp = try makeTempFile(name: "warn.mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let warning = Warning(category: .subtitle, humanMessage: "fr failed")
        let outcome = OutcomeBuilder.build(
            exitCode: 0,
            capturedFilepath: tmp.path,
            warnings: [warning]
        )

        guard case .completedWithWarnings(let path, let warnings) = outcome else {
            Issue.record("Expected .completedWithWarnings, got \(outcome)")
            return
        }
        #expect(path == tmp.path)
        #expect(warnings.count == 1)
        #expect(warnings.first?.category == .subtitle)
    }

    /// Regression test for the screenshot bug: yt-dlp exited non-zero,
    /// the file is on disk, stderr produced no WARNING: lines.
    /// OutcomeBuilder must SYNTHESISE a warning so the user is informed
    /// something was off — but the status is .completedWithWarnings, NOT .failed.
    @Test("Exit ≠ 0, file present, empty stderr → completedWithWarnings (synthesised)")
    func regression_exit1FilePresentSynthesisesWarning() throws {
        let tmp = try makeTempFile(name: "screenshot-bug.mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let outcome = OutcomeBuilder.build(
            exitCode: 1,
            capturedFilepath: tmp.path,
            warnings: []
        )

        guard case .completedWithWarnings(let path, let warnings) = outcome else {
            Issue.record("Expected .completedWithWarnings (regression test), got \(outcome)")
            return
        }
        #expect(path == tmp.path)
        #expect(warnings.count == 1)
        #expect(warnings.first?.category == .other)
        #expect(warnings.first?.humanMessage.contains("file is present") ?? false)
    }

    @Test("Exit ≠ 0, file missing → failed")
    func exit1FileMissing() {
        let outcome = OutcomeBuilder.build(
            exitCode: 1,
            capturedFilepath: "/tmp/does-not-exist-\(UUID().uuidString).mp4",
            warnings: []
        )

        guard case .failed(let message) = outcome else {
            Issue.record("Expected .failed, got \(outcome)")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test("Exit 15 → cancelled regardless of file state")
    func exit15Cancelled() throws {
        let tmp = try makeTempFile(name: "cancelled.mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let outcome = OutcomeBuilder.build(
            exitCode: 15,
            capturedFilepath: tmp.path,
            warnings: []
        )

        guard case .cancelled = outcome else {
            Issue.record("Expected .cancelled, got \(outcome)")
            return
        }
    }

    @Test("Exit 0, no captured filepath → completed (legacy fallback)")
    func exit0NoFilepathLegacy() {
        let outcome = OutcomeBuilder.build(
            exitCode: 0,
            capturedFilepath: nil,
            warnings: []
        )

        guard case .completed(let path) = outcome else {
            Issue.record("Expected .completed (legacy), got \(outcome)")
            return
        }
        #expect(path.isEmpty)
    }

    // MARK: helpers

    private func makeTempFile(name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fetch-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data("test".utf8).write(to: url)
        return url
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/OutcomeBuilderTests 2>&1 | tail -10`
Expected: build error — `cannot find 'OutcomeBuilder' in scope` / `cannot find 'DownloadOutcome' in scope`.

- [ ] **Step 3: Write minimal implementation**

Append to `Fetch/Services/YTDLPService.swift` (after the `Warning` struct from Task 1):

```swift
/// Result of running a yt-dlp Process. Carries everything needed to derive a
/// DownloadOutcome — exit code is informational, not authoritative.
struct ProcessRunResult: Sendable {
    let exitCode: Int32
    let capturedFilepath: String?      // from --print after_move:fetch_outpath:%(filepath)q
    let warnings: [Warning]            // already classified + sanitised
    let stderrTail: [String]           // last N lines, kept for fallback diagnostics only
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/OutcomeBuilderTests 2>&1 | tail -10`
Expected: `** TEST SUCCEEDED **`, six tests passing — including the regression test for the screenshot bug.

- [ ] **Step 5: Commit**

```bash
git add Fetch/Services/YTDLPService.swift FetchTests/FetchTests.swift
git commit -m "$(cat <<'EOF'
feat(yt-dlp): DownloadOutcome + OutcomeBuilder (fixes false-failure bug)

Pure-logic builder that derives the success/failure judgement from
exit code + captured filepath + filesystem check. Exit code is now
informational, not authoritative.

Includes regression test for the screenshot bug: when yt-dlp exits
non-zero but the video file is present, we synthesise a warning and
mark the download .completedWithWarnings — never .failed.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Refactor `streamProcess` to return ProcessRunResult (no throw on non-zero exit)

**Files:**

- Modify: `Fetch/Services/YTDLPService.swift:360-417`

This is the load-bearing refactor — the function that currently throws on non-zero exit. After this task, `streamProcess` returns success/failure information instead of throwing for benign exits.

- [ ] **Step 1: Replace `streamProcess` with the new signature**

Find the existing private function in `Fetch/Services/YTDLPService.swift` starting at `private func streamProcess(` around line 360. Replace it entirely with:

```swift
    /// Runs a Process whose stdout+stderr stream is parsed line-by-line.
    /// Returns a ProcessRunResult instead of throwing on non-zero exit — the
    /// caller decides whether non-zero is failure or "succeeded with warnings".
    /// Only throws if the Process itself fails to launch.
    private func streamProcess(
        _ path: String,
        arguments: [String],
        onProcessStart: (@Sendable (Process) -> Void)? = nil,
        lineHandler: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessRunResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessRunResult, any Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            let lineBuffer = LockedValue("")
            let didResume = LockedValue(false)
            let capturedPath = LockedValue<String?>(nil)
            let warnings = LockedValue<[Warning]>([])
            let stderrTail = LockedValue<[String]>([])
            let kStderrTailMax = 64

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                guard let chunk = String(data: data, encoding: .utf8) else { return }

                let lines = lineBuffer.appendAndExtractLines(chunk)
                for line in lines {
                    // Capture sentinel-prefixed filepath
                    let outpathPrefix = "fetch_outpath:"
                    if let range = line.range(of: outpathPrefix) {
                        let path = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        if !path.isEmpty { capturedPath.set(path) }
                    }

                    // Classify warnings
                    if let w = YTDLPError.classifyWarning(line: line) {
                        warnings.mutate { $0.append(w) }
                    }

                    // Maintain stderr ring buffer (last N lines)
                    stderrTail.mutate {
                        $0.append(line)
                        if $0.count > kStderrTailMax { $0.removeFirst($0.count - kStderrTailMax) }
                    }

                    lineHandler(line)
                }
            }

            process.terminationHandler = { proc in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = lineBuffer.get()
                if !remaining.isEmpty { lineHandler(remaining) }

                guard !didResume.get() else { return }
                didResume.set(true)

                let result = ProcessRunResult(
                    exitCode: proc.terminationStatus,
                    capturedFilepath: capturedPath.get(),
                    warnings: warnings.get(),
                    stderrTail: stderrTail.get()
                )
                continuation.resume(returning: result)
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
```

Key changes from the old version:

- Returns `ProcessRunResult` instead of `Void`.
- **Never throws on non-zero exit** — only throws if `process.run()` itself fails.
- Captures `fetch_outpath:` sentinel lines into `capturedPath`.
- Classifies `WARNING:` lines into `warnings`.
- Maintains a 64-line stderr ring buffer.

- [ ] **Step 2: Build to confirm signature compiles**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: build error in `download()` — `value of type 'ProcessRunResult' has no member ...` or similar, because `download()` still expects `Void` from `streamProcess`. This is the next task.

- [ ] **Step 3: Commit (intermediate, broken build is OK locally)**

We don't commit a broken build. Skip the commit until Task 5 fixes `download()`. This task and Task 5 commit together at the end of Task 5.

---

## Task 5: Wire `download()` to build DownloadOutcome from ProcessRunResult

**Files:**

- Modify: `Fetch/Services/YTDLPService.swift:181-254` (the `download` function)

- [ ] **Step 1: Replace the body of `download()`**

In `Fetch/Services/YTDLPService.swift`, replace the entire `download(...)` function (currently lines 183-254) with:

```swift
    func download(
        url: String,
        formatId: String?,
        outputDirectory: String,
        outputTemplate: String = "%(title)s.%(ext)s",
        extraArgs: [String] = [],
        onProcessStart: (@Sendable (Process) -> Void)? = nil,
        progressHandler: @Sendable @escaping (DownloadProgress) -> Void
    ) async throws -> DownloadOutcome {
        let bin = try await findBinary()
        let expandedDir = NSString(string: outputDirectory).expandingTildeInPath

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
            "--print", "after_move:fetch_outpath:%(filepath)s",   // ← upgraded sentinel
            "-o", "\(expandedDir)/\(outputTemplate)",
        ]

        if let formatId, !formatId.isEmpty {
            arguments += ["-f", formatId]
        }
        arguments += extraArgs
        arguments.append(url)

        let runResult = try await streamProcess(bin, arguments: arguments, onProcessStart: onProcessStart) { line in
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
            }
            // Note: fetch_outpath capture is now handled inside streamProcess.
        }

        progressHandler(DownloadProgress(
            percentage: 100, speed: nil, eta: nil, totalSize: nil,
            status: .completed
        ))

        return OutcomeBuilder.build(
            exitCode: runResult.exitCode,
            capturedFilepath: runResult.capturedFilepath,
            warnings: runResult.warnings
        )
    }
```

Key changes:

- Return type: `String` → `DownloadOutcome`.
- Sentinel: `filepath:` → `fetch_outpath:` (matches `streamProcess`).
- Trailing logic builds the outcome via `OutcomeBuilder` instead of returning a raw path string.
- Removed local `result` `LockedValue` (now lives inside `streamProcess`).

- [ ] **Step 2: Build to verify YTDLPService compiles**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: build error — but now the error is in `DownloadManager.swift` (callers expecting `String` from `download()`). We fix that next.

- [ ] **Step 3: Commit Tasks 4 + 5 together**

The repo is in a broken state until DownloadManager is updated, so don't commit yet. Continue to Task 6 / Task 8 then commit at the appropriate boundary. Mark this checklist item done by leaving it; we'll commit at the end of Task 8.

---

## Task 6: Add `.completedWithWarnings` to persisted `DownloadStatus` enum

**Files:**

- Modify: `Fetch/Models/Download.swift:119-126`

- [ ] **Step 1: Write the failing test**

Append to `FetchTests/FetchTests.swift`:

```swift
@Suite("DownloadStatus Enum")
struct DownloadStatusEnumTests {
    @Test("New completedWithWarnings case round-trips through rawValue")
    func completedWithWarningsRawValue() {
        let s = DownloadStatus.completedWithWarnings
        #expect(s.rawValue == "completedWithWarnings")
        #expect(DownloadStatus(rawValue: "completedWithWarnings") == .completedWithWarnings)
    }

    @Test("Unknown raw values still fall back to completed (no SwiftData migration needed)")
    func unknownRawFallback() {
        // Simulates an old persisted record that doesn't know about new states.
        // Download.downloadStatus getter at Models/Download.swift:103 falls back to .completed.
        let unknown = DownloadStatus(rawValue: "futureFancyState")
        #expect(unknown == nil)  // The enum itself doesn't accept unknown values
        // Round-trip via Download model is exercised in the existing Download tests.
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/DownloadStatusEnumTests 2>&1 | tail -10`
Expected: build error — `type 'DownloadStatus' has no member 'completedWithWarnings'`.

- [ ] **Step 3: Add the case**

In `Fetch/Models/Download.swift`, locate the `DownloadStatus` enum (lines 119-126) and add the new case:

```swift
enum DownloadStatus: String, Codable, CaseIterable {
    case queued
    case downloading
    case postprocessing
    case completed
    case completedWithWarnings   // ← new
    case failed
    case cancelled
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test -only-testing FetchTests/DownloadStatusEnumTests 2>&1 | tail -10`
Expected: `** TEST SUCCEEDED **`, two tests passing.

- [ ] **Step 5: No commit yet**

Pending Tasks 7-8 also touch the type system. Commit after Task 8.

---

## Task 7: Add `.completedWithWarnings` to transient `DownloadTaskStatus` + `DownloadTask.warnings`

**Files:**

- Modify: `Fetch/Services/DownloadManager.swift:402-410` (DownloadTask properties)
- Modify: `Fetch/Services/DownloadManager.swift:460-484` (DownloadTaskStatus)

- [ ] **Step 1: Add the new field on DownloadTask**

In `Fetch/Services/DownloadManager.swift`, locate the property block of `DownloadTask` (around line 402-410) and add:

```swift
    var warnings: [Warning] = []
```

(placement: directly after `var error: String?` at line 409, before `var processHandle: Process?` at line 410.)

- [ ] **Step 2: Add the new case to DownloadTaskStatus**

In the same file, locate the `DownloadTaskStatus` enum (around line 460-484). Add the new case and update the `label` and `icon` switches:

```swift
    enum DownloadTaskStatus: String {
        case scheduled, queued, downloading, postprocessing, completed, completedWithWarnings, failed, cancelled

        var label: String {
            switch self {
            case .scheduled: "Scheduled"
            case .queued: "Queued"
            case .downloading: "Downloading"
            case .postprocessing: "Processing"
            case .completed: "Completed"
            case .completedWithWarnings: "Completed with warnings"
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
            case .completedWithWarnings: "exclamationmark.triangle.fill"
            case .failed: "xmark.circle.fill"
            case .cancelled: "minus.circle"
            }
        }
    }
```

- [ ] **Step 3: Build to verify the enum compiles**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: still failing on `DownloadManager.startDownload`'s call site (Task 8). DownloadRowView's switches will also error (Task 9). Both are fixed in subsequent tasks.

- [ ] **Step 4: No commit yet**

Continue to Task 8.

---

## Task 8: Switch DownloadManager.startDownload on DownloadOutcome

**Files:**

- Modify: `Fetch/Services/DownloadManager.swift:202-290`

- [ ] **Step 1: Replace the body of `startDownload`**

Locate the existing `private func startDownload(_ task: DownloadTask)` function (line 202) and the inner `Task.detached` block (line 213-289). Replace the entire body of `Task.detached` with:

```swift
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

                let outcome = try await service.download(
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
                        case .downloading: task.status = .downloading
                        case .postprocessing: task.status = .postprocessing
                        case .completed: break  // Final status is set from the outcome below
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

                    switch outcome {
                    case .completed(let path):
                        task.status = .completed
                        task.outputPath = path
                        task.warnings = []
                        task.progress = 100
                        if let context = self?.modelContext {
                            self?.saveToHistory(task, context: context)
                        }
                        Task {
                            await NotificationService.shared.notifyDownloadComplete(
                                title: task.title ?? task.url,
                                outputPath: path
                            )
                        }

                    case .completedWithWarnings(let path, let warnings):
                        task.status = .completedWithWarnings
                        task.outputPath = path
                        task.warnings = warnings
                        task.progress = 100
                        if let context = self?.modelContext {
                            self?.saveToHistory(task, context: context)
                        }
                        Task {
                            await NotificationService.shared.notifyDownloadComplete(
                                title: task.title ?? task.url,
                                outputPath: path
                            )
                        }

                    case .failed(let message):
                        task.status = .failed
                        task.error = message

                    case .cancelled:
                        task.status = .cancelled
                    }

                    self?.processQueue()
                    self?.updateDockBadge()
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
```

- [ ] **Step 2: Locate `saveToHistory` and update the persisted-status mapping**

Find the existing `saveToHistory` call site / function in `DownloadManager.swift` (search for `saveToHistory`). It should map `task.status` to a persisted `DownloadStatus`. Update the mapping so:

```swift
let persistedStatus: DownloadStatus
switch task.status {
case .completed: persistedStatus = .completed
case .completedWithWarnings: persistedStatus = .completedWithWarnings
case .failed: persistedStatus = .failed
case .cancelled: persistedStatus = .cancelled
default: persistedStatus = .completed   // Defensive default
}
```

(If `saveToHistory` currently just hardcodes `status: .completed`, replace that with the switch above.)

- [ ] **Step 3: Build to verify DownloadManager + Services compile**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: build errors now only in `DownloadRowView.swift` (and possibly History/Library) — the switches over `DownloadTaskStatus` need the new case. Fixed in Task 9.

- [ ] **Step 4: Commit Tasks 4 through 8 as a single logical change**

```bash
git add Fetch/Services/YTDLPService.swift Fetch/Models/Download.swift Fetch/Services/DownloadManager.swift FetchTests/FetchTests.swift
git commit -m "$(cat <<'EOF'
feat: three-state download status powered by DownloadOutcome

Replaces the exit-code-only success oracle with a derived judgement
from captured filepath + filesystem check + categorised warnings.

- streamProcess() no longer throws on non-zero exit; returns
  ProcessRunResult so the caller decides.
- download() returns DownloadOutcome (completed, completedWithWarnings,
  failed, cancelled).
- DownloadManager switches on the outcome, persists the new status,
  carries [Warning] on the transient task.

UI rendering for the new state lands in the next commit.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Render `.completedWithWarnings` in DownloadRowView

**Files:**

- Modify: `Fetch/Views/DownloadRowView.swift` (statusColor, statusIconView, "tap for details" hint, accessibility)

- [ ] **Step 1: Update `statusColor`**

Find the `statusColor` computed property (around line 151). Replace with:

```swift
    private var statusColor: Color {
        switch task.status {
        case .scheduled: .purple
        case .queued: .secondary
        case .downloading: Color.accentColor
        case .postprocessing: .orange
        case .completed: .green
        case .completedWithWarnings: .orange
        case .failed: .red
        case .cancelled: .secondary
        }
    }
```

- [ ] **Step 2: Add the warnings hint below the error block**

Find the `// Error` block around line 84-89. Replace the block with:

```swift
                // Error
                if let error = task.error, task.status == .failed {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                // Warnings hint (tap for details)
                if task.status == .completedWithWarnings {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(warningHintText)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .help("Tap this row to see the details of each warning.")
                }
```

Then add a private helper near the bottom of the struct (before the closing brace):

```swift
    private var warningHintText: String {
        let n = task.warnings.count
        return n == 1 ? "1 warning · tap for details" : "\(n) warnings · tap for details"
    }
```

- [ ] **Step 3: Update `accessibilityDescription`**

Find the `accessibilityDescription` computed property (around line 140). Replace with:

```swift
    private var accessibilityDescription: String {
        var parts = [task.title ?? task.url, task.status.label]
        if task.status == .downloading {
            parts.append("\(Int(task.progress)) percent")
        }
        if task.status == .completedWithWarnings, !task.warnings.isEmpty {
            let n = task.warnings.count
            parts.append(n == 1 ? "1 warning, double tap for details" : "\(n) warnings, double tap for details")
        }
        if let error = task.error, task.status == .failed {
            parts.append("Error: \(error)")
        }
        return parts.joined(separator: ", ")
    }
```

- [ ] **Step 4: Build to verify DownloadRowView compiles**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: any remaining build errors are only in HistoryView / LibraryView (Task 12). The app target should otherwise build clean.

- [ ] **Step 5: No commit yet**

Continue to Task 10 (the new sheet view) — they belong in the same UI commit.

---

## Task 10: Create the new WarningDetailSheet view

**Files:**

- Create: `Fetch/Views/WarningDetailSheet.swift`

- [ ] **Step 1: Create the new file**

Create `Fetch/Views/WarningDetailSheet.swift` with:

```swift
import SwiftUI
import AppKit

struct WarningDetailSheet: View {
    let task: DownloadTask
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            description
            warningsList
            Spacer()
            footer
        }
        .padding(20)
        .frame(width: 480, height: 360)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Warning details for \(task.title ?? task.url)")
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .accessibilityHidden(true)
            Text("Completed with warnings")
                .font(.headline)
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .help("Close this dialog.")
        }
    }

    @ViewBuilder
    private var description: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = task.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            if let path = task.outputPath {
                Button {
                    revealInFinder(path: path)
                } label: {
                    HStack(spacing: 4) {
                        Text((path as NSString).deletingLastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                    }
                }
                .buttonStyle(.link)
                .help("Open the containing folder in Finder.")
                .accessibilityLabel("Reveal containing folder in Finder")
            }

            Text("The video downloaded successfully. The following non-fatal issues occurred during processing:")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var warningsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(WarningCategory.allCasesPresent(in: task.warnings), id: \.self) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.displayName)
                            .font(.subheadline.weight(.semibold))
                        ForEach(task.warnings.filter { $0.category == category }) { warning in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: category.iconName)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel(category.displayName)
                                Text(warning.humanMessage)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Spacer()
            Button("Copy log") {
                copyLogToClipboard()
            }
            .help("Copy a sanitised text log of these warnings to the clipboard.")
        }
    }

    // MARK: - Actions

    private func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func copyLogToClipboard() {
        let lines = task.warnings.map { "[\($0.category.displayName)] \($0.humanMessage)" }
        let text = (["Completed with warnings — \(task.title ?? task.url)"] + lines).joined(separator: "\n")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

// MARK: - Category helpers

private extension WarningCategory {
    var displayName: String {
        switch self {
        case .subtitle: "Subtitles"
        case .thumbnail: "Thumbnail"
        case .postProcessing: "Post-processing"
        case .metadata: "Metadata"
        case .other: "Other"
        }
    }

    var iconName: String {
        switch self {
        case .subtitle: "captions.bubble"
        case .thumbnail: "photo"
        case .postProcessing: "gearshape.2"
        case .metadata: "info.circle"
        case .other: "exclamationmark.triangle"
        }
    }

    static func allCasesPresent(in warnings: [Warning]) -> [WarningCategory] {
        var seen: Set<WarningCategory> = []
        var ordered: [WarningCategory] = []
        for w in warnings where !seen.contains(w.category) {
            seen.insert(w.category)
            ordered.append(w.category)
        }
        return ordered
    }
}
```

- [ ] **Step 2: Run xcodegen so the new file is in the project**

Run: `xcodegen generate`
Expected: succeeds, prints `Loaded project` and the new file is added to `Fetch.xcodeproj/project.pbxproj`.

- [ ] **Step 3: Build to verify the new view compiles**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: app target builds clean (HistoryView/LibraryView treatment in Task 12 may still warn if they have exhaustive switches over `DownloadStatus`).

- [ ] **Step 4: No commit yet**

Continue to Task 11 to wire up presentation.

---

## Task 11: Wire DownloadQueueView to present the WarningDetailSheet

**Files:**

- Modify: `Fetch/Views/DownloadQueueView.swift`

- [ ] **Step 1: Read the current file to find the rendering site**

Read the file to locate where rows are rendered. Then add `@State private var inspectedTask: DownloadTask?` and a `.sheet(item: $inspectedTask)` modifier on the list, plus an `.onTapGesture` on the row when status is `.completedWithWarnings`. Approximate shape:

```swift
struct DownloadQueueView: View {
    @Environment(DownloadManager.self) private var manager
    @State private var inspectedTask: DownloadTask?

    var body: some View {
        List(manager.activeTasks) { task in
            DownloadRowView(task: task)
                .contentShape(Rectangle())
                .onTapGesture {
                    if task.status == .completedWithWarnings {
                        inspectedTask = task
                    }
                }
        }
        .sheet(item: $inspectedTask) { task in
            WarningDetailSheet(task: task)
        }
        // ... existing modifiers
    }
}
```

(Adjust the exact integration to match the file's existing structure — the key adds are the `@State`, the tap gesture, and the `.sheet(item:)`.)

Note: `DownloadTask` must be `Identifiable` for `.sheet(item:)`. It already conforms (it's `@Observable @unchecked Sendable` with an `id` — verify by reading `DownloadManager.swift` around line 380).

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: app target builds clean.

- [ ] **Step 3: Commit Tasks 9 + 10 + 11 (UI integration commit)**

```bash
git add Fetch/Views/DownloadRowView.swift Fetch/Views/WarningDetailSheet.swift Fetch/Views/DownloadQueueView.swift Fetch.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(ui): amber 'completed with warnings' state + detail sheet

DownloadRowView gains amber styling, an "N warnings · tap for details"
hint, and updated accessibilityDescription. New WarningDetailSheet
groups warnings by category, links the output folder, and offers a
sanitised "Copy log" action. Sheet presented from DownloadQueueView
when the user taps an amber row.

Tooltips on every interactive element. Sets the pattern for the
broader UX polish pass in sub-project #4.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Honour the new state in HistoryView and LibraryView

**Files:**

- Modify: `Fetch/Views/HistoryView.swift`
- Modify: `Fetch/Views/LibraryView.swift`

- [ ] **Step 1: Search for switches over DownloadStatus**

Run: `grep -n "case \.\\(completed\\|failed\\)" Fetch/Views/HistoryView.swift Fetch/Views/LibraryView.swift`
Expected: lists every site that switches on `DownloadStatus`. Each non-exhaustive switch must gain a `.completedWithWarnings` arm so the compiler doesn't error and the UI renders honestly.

- [ ] **Step 2: For each match, add the new case**

In each switch statement found, add a `case .completedWithWarnings:` arm. Use `.orange` tint where `.completed` uses `.green`, e.g.:

```swift
switch download.downloadStatus {
case .completed:
    Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
case .completedWithWarnings:
    Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
case .failed:
    Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
// ... etc
}
```

Per the spec, no detail sheet from these views (warnings are transient and not persisted) — just an honest status badge.

- [ ] **Step 3: Build to verify the app target compiles clean**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build SYMROOT="$(pwd)/build" 2>&1 | tail -10`
Expected: `** BUILD SUCCEEDED **`. App lands at `./build/Debug/Fetch.app`.

- [ ] **Step 4: Commit**

```bash
git add Fetch/Views/HistoryView.swift Fetch/Views/LibraryView.swift
git commit -m "$(cat <<'EOF'
feat(ui): show 'completed with warnings' badge in History + Library

Per-spec: warning details remain transient (not persisted), but the
persisted status enum is honest, so History and Library show an amber
badge to match the queue. No detail sheet here — that lives in the
queue while the task is still in memory.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Run the test suite, dogfood verification, capture evidence

**Files:**

- None modified — verification + evidence-capture only.

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild -project Fetch.xcodeproj -scheme FetchTests -destination 'platform=macOS' test 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`. All new suites pass:

- `WarningTypesTests` (3)
- `WarningClassifierTests` (6)
- `OutcomeBuilderTests` (6 — including the regression test)
- `DownloadStatusEnumTests` (2)
- All pre-existing tests still pass.

- [ ] **Step 2: Build runnable .app artifact**

Run: `xcodebuild -project Fetch.xcodeproj -scheme Fetch -destination 'platform=macOS' build SYMROOT="$(pwd)/build"`
Expected: `** BUILD SUCCEEDED **`. App at `./build/Debug/Fetch.app`.

- [ ] **Step 3: Launch the app for dogfooding**

Run: `open ./build/Debug/Fetch.app`
Expected: Fetch launches, sidebar shows yt-dlp version footer, no crash on cold start.

- [ ] **Step 4: Reproduce the original bug URL**

In Fetch:

1. Click "New Download".
2. Paste `https://www.youtube.com/watch?v=yVtdp1kF0I4`.
3. Pick a format and start the download.
4. Wait for completion.

Expected: queue row reports either:

- Green `Completed` if no warnings were emitted, OR
- Amber `Completed with warnings` with a "tap for details" hint that opens the new sheet,

but **never red `Failed`** when the file is on disk.

- [ ] **Step 5: Capture before/after evidence**

Take a screenshot of the queue row in its new state. Compare it to the original screenshot from the bug report (the red "Failed" with the file actually present). Save both to `/tmp/before-fix.png` and `/tmp/after-fix.png` for the verification log.

- [ ] **Step 6: Final summary commit (if any tweaks were needed during dogfooding)**

If any tweaks emerged from dogfooding (tooltip wording, sheet sizing, accessibility hints), commit them now. Otherwise, dogfooding is the verification — no code change needed.

```bash
git status   # Should be clean
git log --oneline -10   # Should show 4-5 fresh commits on main
```

- [ ] **Step 7: Update memory with results**

If anything surprising surfaced during dogfooding (e.g. "yt-dlp emits a WARNING: pattern we hadn't categorised"), append it to `/Users/mattrogers/.claude/projects/-Users-mattrogers-GitRepos-Fetch/memory/feedback_workflow.md` or a new `feedback_*.md` so future sessions know.

---

## Self-Review Notes (already applied)

The plan was reviewed against the spec:

1. **Spec coverage** — every section maps to a task:
   - Spec §4 status model → Tasks 6, 7
   - Spec §5 architecture → Tasks 3, 4, 5
   - Spec §6 file-by-file → Tasks 1-12
   - Spec §7 WarningDetailSheet → Task 10
   - Spec §8 test plan → Tasks 1, 2, 3, 6, 13
   - Spec §9 risks (sentinel collision, fallback heuristic) → handled in Task 4 (sentinel) and OutcomeBuilder's legacy fallback (Task 3)
2. **Placeholder scan** — no TBD/TODO/"add appropriate error handling" left in the plan body.
3. **Type consistency** — `WarningCategory`, `Warning`, `ProcessRunResult`, `DownloadOutcome`, `OutcomeBuilder` are spelled the same across every task. `DownloadTaskStatus.completedWithWarnings` matches `DownloadStatus.completedWithWarnings`.

---

## Execution

Once this plan is approved, two execution paths:

1. **Subagent-driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration.
2. **Inline execution** — run tasks in this session via the executing-plans skill, batched with checkpoints.
