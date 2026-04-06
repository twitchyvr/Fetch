import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Download.dateCreated, order: .reverse) private var downloads: [Download]

    @State private var searchText = ""
    @State private var selectedDownload: Download?
    @State private var showClearConfirmation = false
    @State private var showFavoritesOnly = false

    var body: some View {
        Group {
            if downloads.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed downloads will appear here.")
                )
            } else {
                List(filteredDownloads, selection: $selectedDownload) { download in
                    HistoryRowView(download: download)
                        .tag(download)
                        .contextMenu {
                            if let path = download.outputPath {
                                Button("Show in Finder") {
                                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                }
                                Button("Open") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                                }
                                Divider()
                            }
                            Button("Copy URL") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(download.url, forType: .string)
                            }
                            Button("Download Again") {
                                manager.enqueue(
                                    url: download.url,
                                    title: download.title,
                                    formatId: download.formatId,
                                    formatDescription: download.formatDescription,
                                    thumbnailURL: download.thumbnailURL,
                                    extractor: download.extractor,
                                    duration: download.duration
                                )
                            }
                            Button(download.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                download.isFavorite.toggle()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                modelContext.delete(download)
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .searchable(text: $searchText, prompt: "Search downloads...")
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !downloads.isEmpty {
                ToolbarItem {
                    Toggle(isOn: $showFavoritesOnly) {
                        Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                    }
                    .toggleStyle(.button)
                    .help("Show favorites only")
                    .accessibilityLabel("Filter favorites")
                }
                ToolbarItem {
                    Button("Clear All", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear Download History",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All (\(downloads.count) items)", role: .destructive) {
                for download in downloads {
                    modelContext.delete(download)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your entire download history. Downloaded files will not be affected.")
        }
    }

    private var filteredDownloads: [Download] {
        var result = downloads

        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query)
                || $0.url.lowercased().contains(query)
                || ($0.extractor?.lowercased().contains(query) ?? false)
            }
        }

        return result
    }
}

struct HistoryRowView: View {
    let download: Download
    @State private var fileExists = true

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or status icon
            if let thumbStr = download.thumbnailURL, let url = URL(string: thumbStr) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: download.downloadStatus == .completed ? "checkmark" : "xmark")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                }
                .frame(width: 56, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
                .overlay(alignment: .bottomTrailing) {
                    if !fileExists {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Design.Colors.warning)
                            .offset(x: 4, y: 4)
                            .accessibilityLabel("File missing from disk")
                    }
                }
            } else {
                Image(systemName: download.downloadStatus == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(download.downloadStatus == .completed ? .green : .red)
                    .font(.title3)
                    .frame(width: 56)
                    .accessibilityHidden(true)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(download.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .tracking(-0.2)
                    .opacity(fileExists ? 1.0 : 0.5)

                HStack(spacing: 6) {
                    if let extractor = download.extractor {
                        Text(extractor)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }

                    if let format = download.formatDescription {
                        Text(format).font(.caption).foregroundStyle(.secondary)
                    }

                    if let duration = download.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    if let size = download.formattedFileSize {
                        Text(size).font(.caption).foregroundStyle(.secondary)
                    }

                    if !fileExists {
                        Text("File missing")
                            .font(.caption)
                            .foregroundStyle(Design.Colors.warning)
                    }
                }
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(download.dateCreated, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(download.title), \(download.extractor ?? ""), \(download.formattedDuration ?? "")\(fileExists ? "" : ", file missing")")
        .task {
            // Check file existence on background thread to avoid scroll jank
            let path = download.outputPath
            let exists = await Task.detached {
                guard let path else { return false }
                return FileManager.default.fileExists(atPath: path)
            }.value
            fileExists = exists
        }
    }
}
