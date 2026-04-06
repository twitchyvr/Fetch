import SwiftUI

/// Sheet for browsing and selecting playlist entries to download.
struct PlaylistPickerView: View {
    let playlist: PlaylistInfo
    @Binding var isPresented: Bool
    let onDownload: ([PlaylistEntry]) -> Void

    @State private var selectedEntries: Set<String> = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Design.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.title)
                            .font(.title3.weight(.semibold))
                            .tracking(-0.3)
                        if let uploader = playlist.uploader {
                            Text(uploader)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(playlist.entries.count) items")
                            .font(.callout.bold())
                        if let total = playlist.totalDuration {
                            Text("Total: \(DurationFormatter.format(total))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Button("Select All") {
                        selectedEntries = Set(filteredEntries.map(\.id))
                    }
                    Button("Deselect All") {
                        selectedEntries.removeAll()
                    }
                    Spacer()
                    Text("\(selectedEntries.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            .padding()

            Divider()

            // Entry list
            List {
                ForEach(filteredEntries) { entry in
                    HStack(spacing: Design.Spacing.md) {
                        Toggle("", isOn: Binding(
                            get: { selectedEntries.contains(entry.id) },
                            set: { isOn in
                                if isOn { selectedEntries.insert(entry.id) }
                                else { selectedEntries.remove(entry.id) }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        // Thumbnail
                        if let thumbURL = entry.thumbnailURL {
                            AsyncImage(url: thumbURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                            }
                            .frame(width: 48, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityHidden(true)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.callout)
                                .lineLimit(1)
                            if let dur = entry.formattedDuration {
                                Text(dur)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        Spacer()

                        Text("#\(entry.index)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .searchable(text: $searchText, prompt: "Search entries...")

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Download \(selectedEntries.count) Items") {
                    let selected = playlist.entries.filter { selectedEntries.contains($0.id) }
                    onDownload(selected)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedEntries.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            // Select all by default
            selectedEntries = Set(playlist.entries.map(\.id))
        }
    }

    private var filteredEntries: [PlaylistEntry] {
        guard !searchText.isEmpty else { return playlist.entries }
        let query = searchText.lowercased()
        return playlist.entries.filter { $0.title.lowercased().contains(query) }
    }
}
