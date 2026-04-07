import SwiftUI

/// Rich detail view for a video — shown from NewDownloadView (pre-download with MediaInfo)
/// or from LibraryView (post-download with Download model).
struct VideoDetailView: View {
    let title: String
    let uploader: String?
    let channelURL: String?
    let channelFollowerCount: Int?
    let duration: TimeInterval?
    let thumbnailURL: URL?
    let description: String?
    let viewCount: Int64?
    let likeCount: Int64?
    let commentCount: Int64?
    let uploadDate: String?
    let tags: [String]
    let categories: [String]
    let webpageURL: String?
    let extractor: String
    let sourceURL: String

    // Post-download fields (nil for pre-download)
    let outputPath: String?
    let fileSize: Int64?
    let formatDescription: String?

    @State private var descriptionExpanded = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Factory initializers

    init(mediaInfo: MediaInfo) {
        self.title = mediaInfo.title
        self.uploader = mediaInfo.uploader
        self.channelURL = mediaInfo.channelURL
        self.channelFollowerCount = mediaInfo.channelFollowerCount
        self.duration = mediaInfo.duration
        self.thumbnailURL = mediaInfo.thumbnailURL
        self.description = mediaInfo.description
        self.viewCount = mediaInfo.viewCount.map { Int64($0) }
        self.likeCount = mediaInfo.likeCount.map { Int64($0) }
        self.commentCount = mediaInfo.commentCount.map { Int64($0) }
        self.uploadDate = mediaInfo.uploadDate
        self.tags = mediaInfo.tags
        self.categories = mediaInfo.categories
        self.webpageURL = mediaInfo.webpageURL
        self.extractor = mediaInfo.extractor
        self.sourceURL = mediaInfo.url
        self.outputPath = nil
        self.fileSize = nil
        self.formatDescription = nil
    }

    init(download: Download) {
        self.title = download.title
        self.uploader = download.uploaderName
        self.channelURL = download.channelURL
        self.channelFollowerCount = nil
        self.duration = download.duration
        self.thumbnailURL = download.thumbnailURL.flatMap { URL(string: $0) }
        self.description = download.videoDescription
        self.viewCount = download.viewCount
        self.likeCount = download.likeCount
        self.commentCount = download.commentCount
        self.uploadDate = nil
        self.tags = download.tagList
        self.categories = []
        self.webpageURL = download.webpageURL
        self.extractor = download.extractor ?? "unknown"
        self.sourceURL = download.url
        self.outputPath = download.outputPath
        self.fileSize = download.fileSize
        self.formatDescription = download.formatDescription
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                thumbnailHeader
                detailContent
            }
        }
        .frame(minWidth: 480, idealWidth: 540, maxWidth: 640,
               minHeight: 400, idealHeight: 600, maxHeight: 800)
        .background(.background)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
        }
    }

    // MARK: - Thumbnail Header

    private var thumbnailHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(height: 240)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 120)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .shadow(radius: 2)

                if let uploader {
                    uploaderRow(uploader)
                }
            }
            .padding(Design.Spacing.lg)
        }
    }

    private func uploaderRow(_ name: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.circle.fill")
                .font(.caption)
            Text(name)
                .font(.callout.weight(.medium))
            if let count = channelFollowerCount {
                Text("·")
                Text(formatCount(Int64(count)) + " subscribers")
                    .font(.caption)
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .shadow(radius: 1)
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.lg) {
            statsRow
            if let description, !description.isEmpty { descriptionSection(description) }
            if !tags.isEmpty || !categories.isEmpty { tagsSection }
            linksSection
            if outputPath != nil { fileInfoSection }
        }
        .padding(Design.Spacing.lg)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Design.Spacing.lg) {
            if let viewCount {
                statItem(icon: "eye.fill", value: formatCount(viewCount), label: "views")
            }
            if let likeCount {
                statItem(icon: "hand.thumbsup.fill", value: formatCount(likeCount), label: "likes")
            }
            if let commentCount {
                statItem(icon: "bubble.left.fill", value: formatCount(commentCount), label: "comments")
            }
            if let duration {
                statItem(icon: "clock.fill", value: DurationFormatter.format(duration), label: "duration")
            }
            if let uploadDate, let formatted = formatUploadDate(uploadDate) {
                statItem(icon: "calendar", value: formatted, label: "uploaded")
            }

            Spacer()

            Text(extractor)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .padding(Design.Spacing.md)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Design.Radius.standard))
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold).monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Description

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            Text("Description")
                .font(.headline)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(descriptionExpanded ? nil : 5)
                .textSelection(.enabled)

            if text.count > 200 {
                Button(descriptionExpanded ? "Show Less" : "Show More") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        descriptionExpanded.toggle()
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            if !categories.isEmpty {
                HStack(spacing: 6) {
                    Text("Category")
                        .font(.headline)
                    ForEach(categories, id: \.self) { cat in
                        Text(cat)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
            }

            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Text("Tags")
                        .font(.headline)

                    FlowLayout(spacing: 6) {
                        ForEach(tags.prefix(20), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                        }
                        if tags.count > 20 {
                            Text("+\(tags.count - 20) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            Text("Links")
                .font(.headline)

            if let webpageURL {
                linkRow(icon: "link", label: "Share URL", value: webpageURL)
            }

            linkRow(icon: "arrow.down.circle", label: "Source URL", value: sourceURL)

            if let channelURL {
                linkRow(icon: "person.circle", label: "Channel", value: channelURL)
            }
        }
    }

    private func linkRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Design.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy \(label)")
        }
        .padding(.vertical, 2)
    }

    // MARK: - File Info (post-download)

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            Text("File")
                .font(.headline)

            if let path = outputPath {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.secondary)
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.callout)
                    Spacer()
                    if let fileSize {
                        let formatter = ByteCountFormatter()
                        Text(formatter.string(fromByteCount: fileSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let formatDescription {
                    HStack {
                        Text("Format:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDescription)
                            .font(.caption)
                    }
                }

                HStack(spacing: Design.Spacing.md) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Open") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(Design.Spacing.md)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Design.Radius.standard))
    }

    // MARK: - Formatting Helpers

    private func formatCount(_ count: Int64) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatUploadDate(_ dateStr: String) -> String? {
        // yt-dlp uses YYYYMMDD format
        guard dateStr.count == 8,
              let year = Int(dateStr.prefix(4)),
              let month = Int(dateStr.dropFirst(4).prefix(2)),
              let day = Int(dateStr.dropFirst(6).prefix(2)) else {
            return dateStr
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = Calendar.current.date(from: components) else { return dateStr }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - FlowLayout (wrapping tag layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0  // Track widest row for parents that need intrinsic width

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                widestRow = max(widestRow, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        widestRow = max(widestRow, x - spacing)

        // Clamp width when proposal is unspecified — never return .infinity to parent
        let reportedWidth = maxWidth.isFinite ? maxWidth : max(widestRow, 0)
        return (CGSize(width: reportedWidth, height: y + rowHeight), positions)
    }
}
