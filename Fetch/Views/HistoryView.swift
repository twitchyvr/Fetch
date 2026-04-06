import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Download.dateCreated, order: .reverse) private var downloads: [Download]

    @State private var searchText = ""
    @State private var selectedDownload: Download?
    @State private var showClearConfirmation = false

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
        guard !searchText.isEmpty else { return downloads }
        let query = searchText.lowercased()
        return downloads.filter {
            $0.title.lowercased().contains(query)
            || $0.url.lowercased().contains(query)
            || ($0.extractor?.lowercased().contains(query) ?? false)
        }
    }
}

struct HistoryRowView: View {
    let download: Download

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: download.downloadStatus == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(download.downloadStatus == .completed ? .green : .red)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(download.title)
                    .font(.callout.bold())
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let extractor = download.extractor {
                        Text(extractor)
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }

                    if let format = download.formatDescription {
                        Text(format)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let duration = download.formattedDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let size = download.formattedFileSize {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(download.dateCreated, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(download.dateCreated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
