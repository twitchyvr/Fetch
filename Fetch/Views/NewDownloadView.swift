import SwiftUI
import SwiftData

struct NewDownloadView: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Preset.dateCreated) private var presets: [Preset]

    let initialURL: String?

    @State private var urlText = ""
    @State private var mediaInfo: MediaInfo?
    @State private var selectedFormat: FormatOption?
    @State private var selectedPreset: Preset?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showFormatPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                urlInputSection
                if isLoading { loadingSection }
                if let error { errorSection(error) }
                if let mediaInfo { mediaInfoSection(mediaInfo) }
            }
            .padding(24)
        }
        .navigationTitle("New Download")
        .onChange(of: initialURL) { _, newValue in
            if let newValue, !newValue.isEmpty, newValue != urlText {
                urlText = newValue
                fetchInfo()
            }
        }
        .onAppear {
            if let initialURL, !initialURL.isEmpty, urlText.isEmpty {
                urlText = initialURL
                fetchInfo()
            }
        }
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("URL")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Paste a video or audio URL...", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { fetchInfo() }

                Button("Paste") {
                    if let content = NSPasteboard.general.string(forType: .string) {
                        urlText = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        fetchInfo()
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Fetch") { fetchInfo() }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.isEmpty || isLoading)
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Fetching media info...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
            Button("Retry") { fetchInfo() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Media Info

    private func mediaInfoSection(_ info: MediaInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and metadata
            HStack(alignment: .top, spacing: 16) {
                if let thumb = info.thumbnailURL {
                    AsyncImage(url: thumb) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(.title3.bold())
                        .lineLimit(2)

                    if let uploader = info.uploader {
                        Text(uploader)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        if let duration = info.formattedDuration {
                            Label(duration, systemImage: "clock")
                        }
                        Label(info.extractor, systemImage: "globe")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Format selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Format")
                        .font(.headline)
                    Spacer()
                    Button("Browse All Formats (\(info.formats.count))") {
                        showFormatPicker = true
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                // Quick presets
                HStack(spacing: 8) {
                    FormatQuickButton(label: "Best", icon: "star.fill", isSelected: selectedFormat == nil) {
                        selectedFormat = nil
                    }

                    ForEach(info.videoFormats.prefix(3)) { format in
                        FormatQuickButton(
                            label: format.resolution ?? format.ext,
                            icon: "film",
                            detail: format.displaySize,
                            isSelected: selectedFormat == format
                        ) {
                            selectedFormat = format
                        }
                    }

                    if let bestAudio = info.audioOnlyFormats.first {
                        FormatQuickButton(
                            label: "Audio",
                            icon: "music.note",
                            detail: bestAudio.displayBitrate,
                            isSelected: selectedFormat == bestAudio
                        ) {
                            selectedFormat = bestAudio
                        }
                    }
                }
            }

            // Preset picker
            if !presets.isEmpty {
                Picker("Preset", selection: $selectedPreset) {
                    Text("None").tag(nil as Preset?)
                    ForEach(presets) { preset in
                        Text(preset.name).tag(preset as Preset?)
                    }
                }
                .pickerStyle(.menu)
            }

            // Download button
            HStack {
                Spacer()
                Button(action: startDownload) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
        }
        .sheet(isPresented: $showFormatPicker) {
            FormatPickerView(
                mediaInfo: info,
                selectedFormat: $selectedFormat
            )
        }
    }

    // MARK: - Actions

    private func fetchInfo() {
        guard !urlText.isEmpty else { return }
        error = nil
        mediaInfo = nil
        isLoading = true

        Task {
            do {
                let info = try await manager.fetchMediaInfo(for: urlText)
                mediaInfo = info
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func startDownload() {
        guard let mediaInfo else { return }

        manager.enqueue(
            url: urlText,
            title: mediaInfo.title,
            formatId: selectedFormat?.id,
            formatDescription: selectedFormat?.displayName,
            preset: selectedPreset,
            thumbnailURL: mediaInfo.thumbnailURL?.absoluteString,
            extractor: mediaInfo.extractor,
            duration: mediaInfo.duration
        )

        // Reset for next download
        urlText = ""
        self.mediaInfo = nil
        selectedFormat = nil
    }
}

// MARK: - Quick Format Button

struct FormatQuickButton: View {
    let label: String
    let icon: String
    var detail: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption.bold())
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 70, minHeight: 50)
            .padding(8)
            .background(
                isSelected ? AnyShapeStyle(.blue.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.5)),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? .blue : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
