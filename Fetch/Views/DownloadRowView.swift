import SwiftUI

struct DownloadRowView: View {
    let task: DownloadTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            HStack {
                Image(systemName: task.status.icon)
                    .foregroundStyle(iconColor)
                    .font(.callout)
                    .accessibilityHidden(true)

                Text(task.title ?? task.url)
                    .font(.callout.bold())
                    .lineLimit(1)

                Spacer()

                statusBadge
            }

            // Progress bar (only during download/postprocess)
            if task.status == .downloading || task.status == .postprocessing {
                ProgressView(value: task.progress, total: 100)
                    .progressViewStyle(ShimmerProgressViewStyle())
                    .accessibilityHidden(true)

                HStack {
                    if task.status == .postprocessing {
                        Text("Post-processing...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(Int(task.progress))%")
                            .font(.caption.monospacedDigit().bold())

                        if let speed = task.speed {
                            Text(speed)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        if let eta = task.eta {
                            Text("ETA \(eta)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let size = task.totalSize {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Error message
            if let error = task.error, task.status == .failed {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .accessibilityLabel("Error: \(error)")
            }

            // Metadata row
            HStack(spacing: 8) {
                if let extractor = task.extractor {
                    Text(extractor)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                if let formatDesc = task.formatDescription {
                    Text(formatDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(task.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [task.title ?? task.url, task.status.label]
        if task.status == .downloading {
            parts.append("\(Int(task.progress)) percent")
        }
        if let error = task.error, task.status == .failed {
            parts.append("Error: \(error)")
        }
        return parts.joined(separator: ", ")
    }

    private var iconColor: Color {
        switch task.status {
        case .queued: .secondary
        case .downloading: .blue
        case .postprocessing: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(task.status.label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
            .accessibilityHidden(true)
    }

    private var badgeColor: Color {
        switch task.status {
        case .queued: .secondary
        case .downloading: .blue
        case .postprocessing: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}
