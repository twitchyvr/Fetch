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
