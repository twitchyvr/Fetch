---
title: Download Success Oracle (Bug Fix)
status: Approved
date: 2026-05-06
sub-project: 1 of 5 — Fetch UX / feature push
related-issues: none (local-first workflow; no GitHub Issue tracking)
---

# Download Success Oracle — Design Spec

## 1. Context

### Observed bug

Fetch reports `Failed` for downloads that succeeded. Reproducible on macOS with yt-dlp 2026.03.17 — the user downloaded `https://www.youtube.com/watch?v=yVtdp1kF0I4` ("NEAT Algorithm Visually Explained"), the queue row showed:

> yt-dlp couldn't process this video. Try a different URL or update yt-dlp.
> **Failed**

while Finder showed the resulting `NEAT Algorithm Visually Explained.mp4` (34.7 MB) plus its `.en.srt` sidecar in `~/Downloads/Fetch/`. Multiple other videos in the same folder exhibit the same pattern — file written, app reports failure.

### Root cause

`Fetch/Services/YTDLPService.swift:398` decides success purely by exit code, accepting only `0` (success) and `15` (SIGTERM/cancel). yt-dlp routinely exits non-zero on benign issues:

- A single subtitle language failed
- A thumbnail couldn't be embedded
- A non-fatal post-processor warned
- `--write-info-json` couldn't write to the directory

When this happens, `streamProcess()` throws `YTDLPError.processError(code: N, rawDetail: "yt-dlp exited with code N")`. Note that the **actual stderr text is discarded** at this point — only the exit-code string is preserved. The sanitiser at `Fetch/Services/YTDLPService.swift:480-550` then fails to match any pattern (because its input is `"yt-dlp exited with code 1"`, not the real stderr) and falls through to the generic message at line 549.

### Why the fix matters first

Sub-projects #2 (yt-dlp self-update + defensive parsing), #3 (screenshot feature), #4 (UX polish), and #5 (settings expansion) all depend on a trustworthy completion signal. Building any of them on a wrapper that lies about success would compound user distrust and force rework.

## 2. Goals

- Eliminate false-failure reports when yt-dlp produces a video file on disk.
- Surface non-fatal issues honestly via a new amber `Completed with warnings` state with a discoverable detail sheet.
- Preserve the existing security-sanitised error path — raw stderr never reaches the UI.
- Keep the change focused: one commit (or small commit chain) directly on `main`, no scope creep into the other sub-projects.

## 3. Non-goals

- Auto-updating yt-dlp itself (deferred to sub-project #2).
- Defensive parsing of yt-dlp's `--help`, `--dump-json`, or progress-template schemas (deferred to sub-project #2).
- Frame-extraction screenshots (sub-project #3).
- General tooltip / accessibility / hierarchy polish (sub-project #4).
- Settings expansion or new ffmpeg controls (sub-project #5).
- Persisting per-warning details into SwiftData. The status enum value is persisted; warning details are transient (cleared when the queue is cleared).

## 4. Status model

| Status                  | Meaning                                                  | Visual                                                                                                             | Source of truth                             |
| ----------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| `completed`             | Video is on disk; no warnings detected.                  | Green check, "Completed" label.                                                                                    | New `DownloadOutcome.completed`             |
| `completedWithWarnings` | Video is on disk; one or more non-fatal issues occurred. | **Amber** triangle, "Completed with warnings" label, "N warning · tap for details" hint. Click row → detail sheet. | New `DownloadOutcome.completedWithWarnings` |
| `failed`                | No usable file on disk; sanitised error message shown.   | Red x, "Failed" label, error text below.                                                                           | New `DownloadOutcome.failed`                |
| `cancelled`             | User-initiated cancel (SIGTERM, exit 15).                | Existing visual.                                                                                                   | New `DownloadOutcome.cancelled`             |

Existing transient states (`scheduled`, `queued`, `downloading`, `postprocessing`) are unchanged.

## 5. Architecture

### Success oracle — three independent signals

After this fix, success is a derived judgement from:

1. **Captured filepath** — yt-dlp's own `--print after_move:filepath` output, prefixed with a sentinel string so it can be grepped out of the merged stdout/stderr stream.
2. **File existence** — `FileManager.default.fileExists(atPath:)` against the captured filepath.
3. **Categorised stderr warnings** — last N lines of stderr captured during the run, classified by pattern.

Exit code becomes informational, not authoritative.

### Argument injection

In `YTDLPService.download()`, append:

```
--print "after_move:fetch_outpath:%(filepath)q"
```

The `fetch_outpath:` prefix is a sentinel so we can distinguish this line from normal yt-dlp output. yt-dlp emits this line **after** all post-processing and the final atomic move — exactly the moment we want.

If the captured filepath is missing (e.g. user has an older yt-dlp without `--print` support, or yt-dlp's print template format changes), we fall back to a directory-scan heuristic:

1. Enumerate the configured output directory.
2. Filter to files whose `contentModificationDate` is ≥ the process start time AND whose extension is in a known media set: `.mp4`, `.mkv`, `.webm`, `.m4a`, `.mp3`, `.opus`, `.wav`, `.flac`.
3. If exactly one match is found, treat it as the captured filepath.
4. If zero matches: status is `completed` only when exit code is 0 (legacy fallback path); otherwise `failed`.
5. If multiple matches: pick the most recently modified one — most likely the just-finished download — and mark `completedWithWarnings` with a synthetic warning noting the ambiguity.

This fallback is intentionally conservative — better to mark `completed` (or `completedWithWarnings`) than `failed` when in doubt, since the user can always inspect their download folder.

### Decision matrix (replaces the line-398 exit-code check)

| Exit code      | `fetch_outpath` captured? | File on disk? | Warnings in stderr? | → Status                                         |
| -------------- | ------------------------- | ------------- | ------------------- | ------------------------------------------------ |
| 0              | yes                       | yes           | none                | `completed`                                      |
| 0              | yes                       | yes           | any                 | `completedWithWarnings`                          |
| 0              | no                        | —             | —                   | `completed` (legacy fallback)                    |
| non-zero, ≠ 15 | yes                       | yes           | any                 | `completedWithWarnings` ← **the screenshot bug** |
| non-zero, ≠ 15 | yes                       | no            | —                   | `failed`                                         |
| non-zero, ≠ 15 | no                        | —             | —                   | `failed` (sanitised message)                     |
| 15 (SIGTERM)   | —                         | —             | —                   | `cancelled`                                      |

### Data flow

```
yt-dlp stdout/stderr (merged)
        │
        ▼
streamProcess line handler ──┬─► progress.status updates UI live
                             │
                             ├─► fetch_outpath line  ──► capturedPath
                             │
                             └─► WARNING:/ERROR: lines ──► ring buffer (last 64 lines)
                                                                      │
                                              process.terminationHandler
                                                                      │
                                                                      ▼
                                                       OutcomeBuilder.build(
                                                         exitCode,
                                                         capturedPath,
                                                         FileManager.exists(capturedPath),
                                                         warnings: classify(ringBuffer)
                                                       )
                                                                      │
                                                                      ▼
                                                  DownloadOutcome (sum type):
                                                    .completed(path: String)
                                                    .completedWithWarnings(path: String, warnings: [Warning])
                                                    .failed(message: String)   // already sanitised
                                                    .cancelled

The actor boundary stays as-is — `DownloadOutcome` is `Sendable`, gets handed to
`DownloadManager` on the MainActor, which maps to `DownloadTaskStatus` and
stamps `task.warnings: [Warning]?`.
```

### Warning model

```swift
enum WarningCategory: String, Sendable {
    case subtitle, thumbnail, postProcessing, metadata, other
}

struct Warning: Sendable, Identifiable, Hashable {
    let id = UUID()
    let category: WarningCategory
    let humanMessage: String   // already sanitised — no paths, hostnames, tokens
    let timestamp: Date        // when the line was emitted
}
```

### Conservative warning classifier

Default policy:

- Lines beginning `WARNING:` (yt-dlp convention) produce a `Warning`.
- Lines matching known post-processor failure patterns (subtitle, thumbnail, metadata embed) produce a `Warning`.
- Format-fallback chatter ("Falling back to alternative format") is ignored — yt-dlp does this routinely and surfacing it would be noise.
- Unknown `WARNING:` text → `Warning(.other, sanitisedText)` — sanitisation drops paths, URLs, hostnames before the text reaches the struct.

The classifier extends the existing `YTDLPError.sanitize(stderr:)` helper; it should remain the single source of truth for stderr → user-safe text mapping.

## 6. File-by-file change list

| File                                                                       | Change                                                                                                                                                                                                                              |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Fetch/Services/YTDLPService.swift:360-417` (`streamProcess`)              | Replace `Void`-returning continuation with `DownloadOutcome`-returning continuation. Add stderr ring buffer (last 64 lines). Add sentinel-prefixed line capture for the after-move filepath. Build outcome in `terminationHandler`. |
| `Fetch/Services/YTDLPService.swift` (new section)                          | Add `DownloadOutcome` sum type, `Warning` struct, `WarningCategory` enum, `OutcomeBuilder` static helper. Extend `sanitize(stderr:)` to emit `(category, message)` pairs as well as the existing single-string output.              |
| `Fetch/Services/YTDLPService.swift` (`download` method)                    | Append `--print after_move:fetch_outpath:%(filepath)q` to args. Return `DownloadOutcome` instead of `String`.                                                                                                                       |
| `Fetch/Services/DownloadManager.swift:202-290` (`startDownload`)           | Switch on `DownloadOutcome` instead of try/catch. Set `task.warnings`, `task.outputPath`, and the appropriate `DownloadTaskStatus` per outcome.                                                                                     |
| `Fetch/Services/DownloadManager.swift:402-410` (`DownloadTask` properties) | Add `var warnings: [Warning] = []`.                                                                                                                                                                                                 |
| `Fetch/Services/DownloadManager.swift:460-484` (`DownloadTaskStatus`)      | Add `case completedWithWarnings`. Label: "Completed with warnings". Icon: `exclamationmark.triangle.fill`.                                                                                                                          |
| `Fetch/Services/DownloadManager.swift` (`saveToHistory`)                   | When persisting, map `.completedWithWarnings` → `DownloadStatus.completedWithWarnings`. Do **not** persist `[Warning]` — only the status.                                                                                           |
| `Fetch/Models/Download.swift:119-126` (`DownloadStatus`)                   | Add `case completedWithWarnings`. No SwiftData migration needed (the underlying column is `String`; older records simply won't have the new raw value).                                                                             |
| `Fetch/Views/DownloadRowView.swift:151-161` (`statusColor`)                | Add `.completedWithWarnings: .orange` (keep `.failed: .red` distinct).                                                                                                                                                              |
| `Fetch/Views/DownloadRowView.swift:130-138` (`statusIconView`)             | Render amber triangle for `.completedWithWarnings`.                                                                                                                                                                                 |
| `Fetch/Views/DownloadRowView.swift:84-89`                                  | Below the error line, add a "N warning · tap for details" hint when status is `.completedWithWarnings`.                                                                                                                             |
| `Fetch/Views/DownloadRowView.swift:140-149` (`accessibilityDescription`)   | Append warning count for VoiceOver users.                                                                                                                                                                                           |
| `Fetch/Views/DownloadQueueView.swift` (74 lines)                           | Add `@State private var inspectedTask: DownloadTask?` + `.sheet(item: $inspectedTask)` presenting `WarningDetailSheet`. Tap-gesture on `.completedWithWarnings` rows opens the sheet.                                               |
| **NEW** `Fetch/Views/WarningDetailSheet.swift`                             | The sheet — see Section 7.                                                                                                                                                                                                          |
| `Fetch/Views/HistoryView.swift` and `Fetch/Views/LibraryView.swift`        | Add visual treatment for `.completedWithWarnings` records (amber tint, no detail sheet — warnings are transient, but the persisted status badge should still be honest).                                                            |
| `project.yml`                                                              | No change — XcodeGen sources `Fetch/Views/` recursively. Run `xcodegen generate` after creating the new file.                                                                                                                       |
| `FetchTests/FetchTests.swift`                                              | Add `OutcomeBuilderTests`, `WarningSanitizerTests`, and the regression test (Section 8).                                                                                                                                            |

## 7. New view: `WarningDetailSheet`

### Layout (480 × 360)

```
┌──────────────────────────────────────────────────────────┐
│ ⚠  Completed with warnings                       Done    │
│ NEAT Algorithm Visually Explained.mp4                    │
│ ~/Downloads/Fetch/  ›  Reveal in Finder                  │
├──────────────────────────────────────────────────────────┤
│ The video downloaded successfully. The following          │
│ non-fatal issues occurred during processing:              │
│                                                           │
│ Subtitles                                                 │
│   ✕  French (fr) subtitle download failed                │
│                                                           │
│ Post-processing                                           │
│   ⚠  Thumbnail couldn't be embedded                      │
│                                                           │
│                                              [Copy log]  │
└──────────────────────────────────────────────────────────┘
```

### Component skeleton

```swift
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
        .accessibilityLabel("Warning details for \(task.title ?? task.url)")
    }

    // header: amber triangle + "Completed with warnings" + Done button
    // description: filename + Reveal-in-Finder link
    // warningsList: warnings grouped by WarningCategory, each row = category icon + humanMessage
    // footer: "Copy log" button
}
```

### Tooltips & accessibility (sets the standard for sub-project #4)

- `.help("Open the containing folder in Finder")` on the path link
- `.help("Copy a sanitised text log of these warnings to the clipboard")` on Copy log
- `.help("Close this dialog")` on Done
- `accessibilityLabel` on each category icon (decorative SF Symbols otherwise unreadable to VoiceOver)
- Sheet's outer `accessibilityLabel` reads the download title for context
- Reveal-in-Finder uses `NSWorkspace.shared.activateFileViewerSelecting(_:)`

## 8. Test plan

Per the global TEST GATE rule, the regression test for this specific bug is non-negotiable.

### Tier 1 — Unit tests, pure (no Process spawning)

Location: `FetchTests/FetchTests.swift` (new test classes appended).

`OutcomeBuilderTests`:

| Test                                                                                | Inputs                                                          | Expected outcome                                                                                                                                                                                                                                                                |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `exit0_filePresent_noWarnings`                                                      | exit 0, capturedPath set, file exists, warnings empty           | `.completed(path)`                                                                                                                                                                                                                                                              |
| `exit0_filePresent_withWarnings`                                                    | exit 0, capturedPath set, file exists, warnings non-empty       | `.completedWithWarnings(path, warnings)`                                                                                                                                                                                                                                        |
| `exit1_filePresent_synthesisesWarning` ← **regression test for the screenshot bug** | exit 1, capturedPath set, file exists, stderr ring buffer empty | `.completedWithWarnings(path, [Warning(.other, "yt-dlp reported errors but the file is present.")])` — `OutcomeBuilder` synthesises this warning whenever exit ≠ 0 yet the file exists, so the user is informed something was off even when stderr produced no `WARNING:` lines |
| `exit1_fileMissing`                                                                 | exit 1, capturedPath nil or file missing                        | `.failed(sanitisedMessage)`                                                                                                                                                                                                                                                     |
| `exit15_anyState`                                                                   | exit 15 (SIGTERM)                                               | `.cancelled`                                                                                                                                                                                                                                                                    |
| `exit2_fileMissing`                                                                 | exit 2, no file                                                 | `.failed` (real usage error)                                                                                                                                                                                                                                                    |

`WarningSanitizerTests`:

| Test                               | Stderr fragment                                    | Expected                                  |
| ---------------------------------- | -------------------------------------------------- | ----------------------------------------- |
| `subtitleFailureRecognised`        | `"WARNING: Some subtitles couldn't be downloaded"` | `Warning(.subtitle, ...)`                 |
| `formatFallbackIgnored`            | `"Falling back to alternative format"`             | no warning produced                       |
| `unknownWarningCategorisedAsOther` | `"WARNING: Unknown thing happened"`                | `Warning(.other, sanitisedText)`          |
| `pathsStrippedFromHumanMessage`    | stderr containing `/Users/...` paths               | `humanMessage` contains no path fragments |

### Tier 2 — Integration tests, real Process spawning

Location: `FetchTests/FetchTests.swift`.

- `IntegrationTests.testRealYTDLPDryRun` — spawn real yt-dlp against a known-good URL with `--simulate`, assert `.completed`. Gated on `which yt-dlp` availability — skip cleanly when yt-dlp is absent rather than failing.

### Tier 3 — Manual dogfood verification

Recorded in the commit message per global EVIDENCE GATE rule.

1. Re-run the exact URL from the original screenshot (`https://www.youtube.com/watch?v=yVtdp1kF0I4`).
2. Expected: queue row goes amber with "Completed with warnings" if anything non-fatal occurred, or green "Completed" if not — but **never red "Failed"** when the file is on disk.
3. Capture before-fix and after-fix screenshots.

## 9. Risks

| Risk                                                                                                                                            | Mitigation                                                                                                                                                                                                                   |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--print after_move:filepath` requires a recent-ish yt-dlp (added 2022.04.08).                                                                  | Fallback to "captured filepath missing" branch in the decision matrix. The user has yt-dlp 2026.03.17, well past this. Document minimum version in README during sub-project #2.                                             |
| The `fetch_outpath:` sentinel could collide with content yt-dlp itself emits in pathological video titles.                                      | Sentinel is unusual enough to be safe in practice; the line parser anchors on the prefix at start-of-line and treats the rest as opaque path text. If a collision is reported, swap to a more entropic sentinel (e.g. UUID). |
| Race between user-deletes-file and post-run existence check.                                                                                    | Edge case; if file is deleted before we check, outcome becomes `.failed`. This is the truthful answer ("user has no file"), even if cause is unusual.                                                                        |
| Mapping `DownloadTaskStatus.completedWithWarnings` to `DownloadStatus` raw value introduces a previously-unseen string in the SwiftData column. | No migration needed — the column is `String`, and `Download.downloadStatus` getter falls back to `.completed` on unknown raw values. New records get the new value; old records keep theirs.                                 |

## 10. Out of scope (deferred)

- Sub-project #2: yt-dlp keep-fresh + version hardening (auto-update, defensive parsing, regression suite vs. multiple yt-dlp versions). The fact that exit-code-only success detection is fragile is itself an argument for #2.
- Sub-project #3: frame-extraction screenshot feature.
- Sub-project #4: tooltip / accessibility / hierarchy polish across the app. The `WarningDetailSheet` follows the patterns this sub-project will codify, but the broader pass is a separate change.
- Sub-project #5: settings expansion (additional ffmpeg / yt-dlp hyperparameters).

## 11. Acceptance

This spec is approved for transition to writing-plans when:

- The user (Matt) reviews this document and signals approval (or requests revisions).
- The next step is invoking the `superpowers:writing-plans` skill to produce a step-by-step implementation plan from this design.
