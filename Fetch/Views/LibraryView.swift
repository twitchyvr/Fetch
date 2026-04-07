import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Download> { $0.status == "completed" },
        sort: \Download.dateCreated,
        order: .reverse
    ) private var downloads: [Download]

    @State private var searchText = ""
    @State private var sortOrder: LibrarySortOrder = .date
    @State private var filterExtractor: String? = nil
    @State private var filterFileStatus: FileStatusFilter = .all
    @State private var filterFormatType: FormatTypeFilter = .all
    @State private var filterFavorites = false
    @State private var viewMode: ViewMode = .list
    @State private var fileExistsCache: [String: Bool] = [:]
    @State private var selectedDownload: Download?

    // MARK: - Body

    var body: some View {
        Group {
            if downloads.isEmpty {
                ContentUnavailableView(
                    "No Media",
                    systemImage: "photo.on.rectangle",
                    description: Text("Downloaded media will appear in your library.")
                )
            } else if filteredAndSorted.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No media matches your current filters.")
                )
            } else {
                switch viewMode {
                case .list:
                    listView
                case .grid:
                    gridView
                }
            }
        }
        .navigationTitle("Library")
        .searchable(text: $searchText, prompt: "Search library...")
        .toolbar { toolbarContent }
        .task { await checkAllFileExistence() }
        .sheet(item: $selectedDownload) { download in
            VideoDetailView(download: download)
        }
    }

    // MARK: - List View

    private var listView: some View {
        List(filteredAndSorted) { download in
            LibraryRowView(
                download: download,
                fileExists: fileExistsCache[download.outputPath ?? ""] ?? true
            )
            .contentShape(Rectangle())
            .onTapGesture { selectedDownload = download }
            .contextMenu { contextMenuItems(for: download) }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: Design.Spacing.md)],
                spacing: Design.Spacing.md
            ) {
                ForEach(filteredAndSorted) { download in
                    LibraryGridItemView(
                        download: download,
                        fileExists: fileExistsCache[download.outputPath ?? ""] ?? true
                    )
                    .onTapGesture { selectedDownload = download }
                    .contextMenu { contextMenuItems(for: download) }
                }
            }
            .padding(Design.Spacing.lg)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker("View", selection: $viewMode) {
                Image(systemName: "list.bullet")
                    .tag(ViewMode.list)
                    .accessibilityLabel("List view")
                Image(systemName: "square.grid.2x2")
                    .tag(ViewMode.grid)
                    .accessibilityLabel("Grid view")
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("View mode")

            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                        Text(order.label).tag(order)
                    }
                }

                Divider()

                Menu("Extractor") {
                    Button("All") { filterExtractor = nil }
                    Divider()
                    ForEach(availableExtractors, id: \.self) { extractor in
                        Button(extractor) { filterExtractor = extractor }
                    }
                }

                Menu("Format") {
                    ForEach(FormatTypeFilter.allCases, id: \.self) { filter in
                        Button(filter.label) { filterFormatType = filter }
                    }
                }

                Menu("File Status") {
                    ForEach(FileStatusFilter.allCases, id: \.self) { filter in
                        Button(filter.label) { filterFileStatus = filter }
                    }
                }

                Toggle("Favorites Only", isOn: $filterFavorites)

                if hasActiveFilters {
                    Divider()
                    Button("Clear Filters") { clearFilters() }
                }
            } label: {
                Label("Filter & Sort", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filter and sort options")

            Menu {
                Button("Export as JSON") {
                    exportAsJSON()
                }
                Button("Export as CSV") {
                    exportAsCSV()
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Export library")

            Text("\(filteredAndSorted.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for download: Download) -> some View {
        if let path = download.outputPath {
            let exists = fileExistsCache[path] ?? true
            if exists {
                Button("Open") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
                Divider()
            }
        }

        Button("View Details") {
            selectedDownload = download
        }

        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(download.url, forType: .string)
        }

        Button(download.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            download.isFavorite.toggle()
        }

        Divider()

        Button("Delete from Library", role: .destructive) {
            modelContext.delete(download)
        }
    }

    // MARK: - Filtering & Sorting

    private var filteredAndSorted: [Download] {
        var result = downloads

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query)
                || $0.url.lowercased().contains(query)
                || ($0.extractor?.lowercased().contains(query) ?? false)
                || ($0.formatDescription?.lowercased().contains(query) ?? false)
            }
        }

        // Filter: favorites
        if filterFavorites {
            result = result.filter { $0.isFavorite }
        }

        // Filter: extractor
        if let filterExtractor {
            result = result.filter { $0.extractor == filterExtractor }
        }

        // Filter: format type
        switch filterFormatType {
        case .all:
            break
        case .video:
            result = result.filter { download in
                guard let desc = download.formatDescription?.lowercased() else { return false }
                return desc.contains("video") || desc.contains("mp4") || desc.contains("webm")
                    || desc.contains("mkv") || desc.contains("avi") || desc.contains("mov")
            }
        case .audio:
            result = result.filter { download in
                guard let desc = download.formatDescription?.lowercased() else { return false }
                return desc.contains("audio") || desc.contains("mp3") || desc.contains("m4a")
                    || desc.contains("opus") || desc.contains("flac") || desc.contains("wav")
                    || desc.contains("aac")
            }
        }

        // Filter: file status
        switch filterFileStatus {
        case .all:
            break
        case .exists:
            result = result.filter { fileExistsCache[$0.outputPath ?? ""] ?? false }
        case .missing:
            result = result.filter { !(fileExistsCache[$0.outputPath ?? ""] ?? true) }
        }

        // Sort
        switch sortOrder {
        case .date:
            break // already sorted by @Query
        case .title:
            result.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .size:
            result.sort { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        case .extractor:
            result.sort { ($0.extractor ?? "").localizedStandardCompare($1.extractor ?? "") == .orderedAscending }
        }

        return result
    }

    private var availableExtractors: [String] {
        let extractors = Set(downloads.compactMap(\.extractor))
        return extractors.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var hasActiveFilters: Bool {
        filterExtractor != nil || filterFileStatus != .all || filterFormatType != .all || filterFavorites
    }

    private func clearFilters() {
        filterExtractor = nil
        filterFileStatus = .all
        filterFormatType = .all
        filterFavorites = false
    }

    // MARK: - File Existence

    private func checkAllFileExistence() async {
        let paths = downloads.compactMap(\.outputPath)
        let results = await Task.detached {
            var map: [String: Bool] = [:]
            for path in paths {
                map[path] = FileManager.default.fileExists(atPath: path)
            }
            return map
        }.value
        fileExistsCache = results
    }

    // MARK: - Export

    private func exportAsJSON() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "fetch-library.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let records = filteredAndSorted.map { download -> [String: Any] in
            var record: [String: Any] = [
                "url": download.url,
                "title": download.title,
                "dateCreated": ISO8601DateFormatter().string(from: download.dateCreated),
                "isFavorite": download.isFavorite
            ]
            if let extractor = download.extractor { record["extractor"] = extractor }
            if let duration = download.duration { record["duration"] = duration }
            if let outputPath = download.outputPath { record["outputPath"] = outputPath }
            if let fileSize = download.fileSize { record["fileSize"] = fileSize }
            return record
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
        } catch {
            NSLog("Failed to export JSON: \(error.localizedDescription)")
        }
    }

    private func exportAsCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "fetch-library.csv"
        panel.allowedContentTypes = [UTType(filenameExtension: "csv") ?? .commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var csv = "url,title,extractor,duration,dateCreated,outputPath,fileSize,isFavorite\n"
        let dateFormatter = ISO8601DateFormatter()

        for download in filteredAndSorted {
            let fields: [String] = [
                csvEscape(download.url),
                csvEscape(download.title),
                csvEscape(download.extractor ?? ""),
                download.duration.map { String($0) } ?? "",
                dateFormatter.string(from: download.dateCreated),
                csvEscape(download.outputPath ?? ""),
                download.fileSize.map { String($0) } ?? "",
                String(download.isFavorite)
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Failed to export CSV: \(error.localizedDescription)")
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

// MARK: - Library Row View

struct LibraryRowView: View {
    let download: Download
    let fileExists: Bool

    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            thumbnailView

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if download.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorited")
                    }
                    Text(download.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .tracking(-0.2)
                        .opacity(fileExists ? 1.0 : 0.5)
                }

                HStack(spacing: 6) {
                    if let extractor = download.extractor {
                        Text(extractor)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }

                    if let format = download.formatDescription {
                        Text(format)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let duration = download.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let size = download.formattedFileSize {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !fileExists {
                        Label("File missing", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(download.dateCreated, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbStr = download.thumbnailURL, let url = URL(string: thumbStr) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                thumbnailPlaceholder
            }
            .frame(width: 56, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
            .overlay(alignment: .bottomTrailing) {
                if !fileExists {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .offset(x: 4, y: 4)
                        .accessibilityHidden(true)
                }
            }
        } else {
            Image(systemName: "doc.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
                .frame(width: 56)
                .accessibilityHidden(true)
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
    }

    private var accessibilityDescription: String {
        var parts = [download.title]
        if let extractor = download.extractor { parts.append(extractor) }
        if let duration = download.formattedDuration { parts.append(duration) }
        if let size = download.formattedFileSize { parts.append(size) }
        if !fileExists { parts.append("file missing") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Library Grid Item View

struct LibraryGridItemView: View {
    let download: Download
    let fileExists: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                if let thumbStr = download.thumbnailURL, let url = URL(string: thumbStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        gridThumbnailPlaceholder
                    }
                } else {
                    gridThumbnailPlaceholder
                }

                if let duration = download.formattedDuration {
                    Text(duration)
                        .font(.caption2.bold())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .padding(Design.Spacing.xs)
                }
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius.standard))
            .overlay {
                if !fileExists {
                    RoundedRectangle(cornerRadius: Design.Radius.standard)
                        .fill(.black.opacity(0.3))
                        .overlay {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                        }
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    if download.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorited")
                    }
                    Text(download.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .opacity(fileExists ? 1.0 : 0.5)
                }

                HStack(spacing: 4) {
                    if let extractor = download.extractor {
                        Text(extractor)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let size = download.formattedFileSize {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var gridThumbnailPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(16/9, contentMode: .fill)
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }

    private var accessibilityDescription: String {
        var parts = [download.title]
        if let extractor = download.extractor { parts.append(extractor) }
        if let duration = download.formattedDuration { parts.append(duration) }
        if !fileExists { parts.append("file missing") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

enum ViewMode: String, CaseIterable {
    case list
    case grid
}

enum LibrarySortOrder: String, CaseIterable {
    case date
    case title
    case size
    case extractor

    var label: String {
        switch self {
        case .date: "Date"
        case .title: "Title"
        case .size: "Size"
        case .extractor: "Extractor"
        }
    }
}

enum FileStatusFilter: String, CaseIterable {
    case all
    case exists
    case missing

    var label: String {
        switch self {
        case .all: "All"
        case .exists: "On Disk"
        case .missing: "Missing"
        }
    }
}

enum FormatTypeFilter: String, CaseIterable {
    case all
    case video
    case audio

    var label: String {
        switch self {
        case .all: "All"
        case .video: "Video"
        case .audio: "Audio"
        }
    }
}
