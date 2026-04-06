import SwiftUI

struct FormatPickerView: View {
    let mediaInfo: MediaInfo
    @Binding var selectedFormat: FormatOption?
    @Environment(\.dismiss) private var dismiss

    @State private var filterType: FormatFilter = .all
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Available Formats")
                    .font(.headline)
                Spacer()
                Text("\(filteredFormats.count) formats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            // Filters
            HStack {
                Picker("Type", selection: $filterType) {
                    ForEach(FormatFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Format table
            Table(filteredFormats, selection: Binding(
                get: { selectedFormat?.id },
                set: { id in
                    selectedFormat = mediaInfo.formats.first { $0.id == id }
                }
            )) {
                TableColumn("ID") { format in
                    Text(format.id)
                        .font(.caption.monospaced())
                }
                .width(min: 40, ideal: 50)

                TableColumn("Type") { format in
                    HStack(spacing: 4) {
                        if format.hasVideo {
                            Image(systemName: "film")
                                .font(.caption2)
                        }
                        if format.hasAudio {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption2)
                        }
                    }
                }
                .width(40)

                TableColumn("Ext") { format in
                    Text(format.ext.uppercased())
                        .font(.caption.bold())
                }
                .width(min: 40, ideal: 50)

                TableColumn("Resolution") { format in
                    Text(format.resolution ?? "-")
                        .font(.caption)
                }
                .width(min: 80, ideal: 100)

                TableColumn("FPS") { format in
                    if let fps = format.fps {
                        Text("\(Int(fps))")
                            .font(.caption.monospacedDigit())
                    } else {
                        Text("-")
                            .foregroundStyle(.tertiary)
                    }
                }
                .width(35)

                TableColumn("Video Codec") { format in
                    Text(format.vcodec ?? "-")
                        .font(.caption)
                        .foregroundStyle(format.vcodec == "none" ? .tertiary : .primary)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Audio Codec") { format in
                    Text(format.acodec ?? "-")
                        .font(.caption)
                        .foregroundStyle(format.acodec == "none" ? .tertiary : .primary)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Size") { format in
                    Text(format.displaySize ?? "-")
                        .font(.caption.monospacedDigit())
                }
                .width(min: 60, ideal: 80)

                TableColumn("Bitrate") { format in
                    Text(format.displayBitrate ?? "-")
                        .font(.caption.monospacedDigit())
                }
                .width(min: 60, ideal: 80)

                TableColumn("Note") { format in
                    Text(format.note ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .width(min: 60, ideal: 80)
            }

            Divider()

            // Footer
            HStack {
                if let selected = selectedFormat {
                    Label(selected.displayName, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.blue)
                } else {
                    Text("Best available format will be used")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear Selection") {
                    selectedFormat = nil
                }
                .disabled(selectedFormat == nil)

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    private var filteredFormats: [FormatOption] {
        var formats = mediaInfo.formats

        switch filterType {
        case .all:
            break
        case .videoAudio:
            formats = formats.filter { $0.hasVideo && $0.hasAudio }
        case .videoOnly:
            formats = formats.filter { $0.isVideoOnly }
        case .audioOnly:
            formats = formats.filter { $0.isAudioOnly }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            formats = formats.filter {
                $0.ext.lowercased().contains(query)
                || ($0.resolution?.lowercased().contains(query) ?? false)
                || ($0.vcodec?.lowercased().contains(query) ?? false)
                || ($0.acodec?.lowercased().contains(query) ?? false)
                || ($0.note?.lowercased().contains(query) ?? false)
                || $0.id.contains(query)
            }
        }

        return formats
    }
}

enum FormatFilter: String, CaseIterable, Identifiable {
    case all, videoAudio, videoOnly, audioOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .videoAudio: "Video+Audio"
        case .videoOnly: "Video Only"
        case .audioOnly: "Audio Only"
        }
    }
}
