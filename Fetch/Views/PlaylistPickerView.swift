import SwiftUI

// MARK: - Download Mode

enum PlaylistDownloadMode: String, CaseIterable, Identifiable {
    case bestQuality = "Best Quality"
    case audioOnly = "Audio Only"
    case videoOnly = "Video Only"
    case transcriptOnly = "Transcript Only"
    case audioAndTranscript = "Audio + Transcript"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bestQuality: "star.fill"
        case .audioOnly: "music.note"
        case .videoOnly: "film"
        case .transcriptOnly: "doc.text"
        case .audioAndTranscript: "music.note.list"
        }
    }

    var description: String {
        switch self {
        case .bestQuality: "Best available video + audio"
        case .audioOnly: "Extract audio file only"
        case .videoOnly: "Video without audio track"
        case .transcriptOnly: "Subtitles/captions as text (no media)"
        case .audioAndTranscript: "Audio file + subtitle file"
        }
    }

    func buildArgs(audioFormat: String) -> [String] {
        switch self {
        case .bestQuality:
            return []
        case .audioOnly:
            return ["--extract-audio", "--audio-format", audioFormat, "--audio-quality", "0"]
        case .videoOnly:
            return ["-f", "bestvideo"]
        case .transcriptOnly:
            return ["--write-auto-subs", "--sub-format", "vtt", "--skip-download", "--sub-langs", "en.*,en"]
        case .audioAndTranscript:
            return ["--extract-audio", "--audio-format", audioFormat, "--audio-quality", "0",
                    "--write-auto-subs", "--sub-format", "vtt", "--sub-langs", "en.*,en"]
        }
    }
}

// MARK: - Playlist Picker View

/// Sheet for browsing and selecting playlist entries to download.
struct PlaylistPickerView: View {
    let playlist: PlaylistInfo
    @Binding var isPresented: Bool
    let onDownload: ([PlaylistEntry], [String]) -> Void

    @State private var selectedEntries: Set<String> = []
    @State private var searchText = ""
    @State private var downloadMode: PlaylistDownloadMode = .bestQuality
    @State private var audioFormat = "mp3"
    @State private var friendlyDuration = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Design.Spacing.md) {
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
                            Button {
                                friendlyDuration.toggle()
                            } label: {
                                Text("Total: \(friendlyDuration ? friendlyFormat(total) : DurationFormatter.format(total))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Click to toggle between HH:MM:SS and friendly format")
                        }
                    }
                }

                // Download mode picker
                VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                    Text("Download Mode")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: Design.Spacing.sm) {
                        ForEach(PlaylistDownloadMode.allCases) { mode in
                            Button {
                                downloadMode = mode
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: mode.icon)
                                        .font(.body)
                                    Text(mode.rawValue)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    downloadMode == mode
                                        ? AnyShapeStyle(Color.accentColor.opacity(0.15))
                                        : AnyShapeStyle(.quaternary),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(downloadMode == mode ? Color.accentColor : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(downloadMode == mode ? Color.accentColor : .primary)
                            .accessibilityAddTraits(downloadMode == mode ? .isSelected : [])
                        }
                    }

                    // Audio format picker (when relevant)
                    if downloadMode == .audioOnly || downloadMode == .audioAndTranscript {
                        HStack {
                            Text("Audio Format:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $audioFormat) {
                                Text("MP3").tag("mp3")
                                Text("M4A").tag("m4a")
                                Text("WAV").tag("wav")
                                Text("FLAC").tag("flac")
                                Text("Opus").tag("opus")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)
                        }
                    }

                    Text(downloadMode.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

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

                let modeLabel = downloadMode == .bestQuality ? "" : " as \(downloadMode.rawValue)"
                Button("Download \(selectedEntries.count) Items\(modeLabel)") {
                    let selected = playlist.entries.filter { selectedEntries.contains($0.id) }
                    let args = downloadMode.buildArgs(audioFormat: audioFormat)
                    onDownload(selected, args)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedEntries.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            selectedEntries = Set(playlist.entries.map(\.id))
        }
    }

    private var filteredEntries: [PlaylistEntry] {
        guard !searchText.isEmpty else { return playlist.entries }
        let query = searchText.lowercased()
        return playlist.entries.filter { $0.title.lowercased().contains(query) }
    }

    private func friendlyFormat(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        return parts.isEmpty ? "0m" : parts.joined(separator: " ")
    }
}
