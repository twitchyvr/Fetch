import SwiftUI

struct DownloadRowView: View {
    let task: DownloadTask
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or status icon
            ZStack {
                if let thumbURL = task.thumbnailURL, let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                    }
                    .frame(width: 64, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)

                    if task.status == .downloading || task.status == .postprocessing {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.black.opacity(0.55))
                            .frame(width: 64, height: 40)
                        Text("\(Int(task.progress))%")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1)
                    }
                } else {
                    statusIconView
                }
            }
            .frame(width: 64, height: 40)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(task.title ?? task.url)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .tracking(-0.2)

                // Scheduled time
                if task.status == .scheduled, let scheduledFor = task.scheduledFor {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("Scheduled for \(scheduledFor, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }

                // Progress bar
                if task.status == .downloading || task.status == .postprocessing {
                    ProgressView(value: task.progress, total: 100)
                        .progressViewStyle(GradientProgressStyle())
                        .accessibilityHidden(true)

                    HStack(spacing: 8) {
                        if task.status == .postprocessing {
                            Text("Post-processing...")
                                .foregroundStyle(Design.Colors.warning)
                        } else {
                            if let speed = task.speed {
                                Text(speed).monospacedDigit()
                            }
                            if let eta = task.eta {
                                Text("ETA \(eta)").monospacedDigit()
                            }
                        }
                        Spacer()
                        if let size = task.totalSize {
                            Text(size)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // Error
                if let error = task.error, task.status == .failed {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                // Metadata row
                HStack(spacing: 6) {
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
                        .truncationMode(.middle)
                        .frame(maxWidth: 200)
                }
            }

            // Status badge
            statusBadge
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.03) : .clear)
        )
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var statusIconView: some View {
        if task.status == .downloading {
            PulsingGlow(color: Color.accentColor)
        } else {
            Image(systemName: task.status.icon)
                .foregroundStyle(statusColor)
                .font(.title3)
        }
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

    private var statusColor: Color {
        switch task.status {
        case .scheduled: .purple
        case .queued: .secondary
        case .downloading: Color.accentColor
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
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
            .foregroundStyle(statusColor)
            .accessibilityHidden(true)
    }
}
