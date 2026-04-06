import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var isDropTargeted = false
    @State private var fetchTask: Task<Void, Never>?
    @State private var batchMode = false
    @State private var batchURLs: [String] = []
    @State private var batchSelected: Set<String> = []

    // Advanced options — args built by AdvancedOptionsView
    @State private var advancedArgs: [String] = []

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
            HStack {
                Text("URL")
                    .font(.headline)
                Spacer()
                Toggle("Batch Mode", isOn: $batchMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Paste multiple URLs — one per line, JSON array, or drop a text file")
            }

            if batchMode {
                batchInputView
            } else {
                singleURLInput
            }
        }
        .padding(isDropTargeted ? 4 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
        )
        .onDrop(of: [.url, .plainText, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var singleURLInput: some View {
        HStack(spacing: 8) {
            TextField("Paste or drop a video/audio URL...", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { fetchInfo() }

            Button("Paste") {
                if let content = NSPasteboard.general.string(forType: .string) {
                    let urls = URLParser.extractURLs(from: content)
                    if urls.count > 1 {
                        batchMode = true
                        batchURLs = urls
                        batchSelected = Set(urls)
                    } else {
                        urlText = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        fetchInfo()
                    }
                }
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("Fetch") { fetchInfo() }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty || isLoading)
        }
    }

    private var batchInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $urlText)
                .font(.body.monospaced())
                .frame(minHeight: 80, maxHeight: 150)
                .border(Color.secondary.opacity(0.2))
                .overlay(alignment: .topLeading) {
                    if urlText.isEmpty {
                        Text("Paste URLs — one per line, JSON array, or mixed text...")
                            .font(.body.monospaced())
                            .foregroundStyle(.tertiary)
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Button("Parse URLs") {
                    let parsed = URLParser.extractURLs(from: urlText)
                    batchURLs = parsed
                    batchSelected = Set(parsed)
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty)

                Button("Paste from Clipboard") {
                    if let content = NSPasteboard.general.string(forType: .string) {
                        urlText = content
                        let parsed = URLParser.extractURLs(from: content)
                        batchURLs = parsed
                        batchSelected = Set(parsed)
                    }
                }

                Spacer()

                if !batchURLs.isEmpty {
                    Text("\(batchURLs.count) URLs found, \(batchSelected.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !batchURLs.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Button("Select All") { batchSelected = Set(batchURLs) }
                        Button("Deselect All") { batchSelected.removeAll() }
                        Spacer()
                        Button("Download \(batchSelected.count) URLs") {
                            startBatchDownload()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(batchSelected.isEmpty)
                    }
                    .font(.caption)
                    .padding(.bottom, 4)

                    List {
                        ForEach(batchURLs, id: \.self) { url in
                            Toggle(isOn: Binding(
                                get: { batchSelected.contains(url) },
                                set: { isOn in
                                    if isOn { batchSelected.insert(url) }
                                    else { batchSelected.remove(url) }
                                }
                            )) {
                                Text(url)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .listStyle(.bordered)
                    .frame(maxHeight: 200)
                }
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
        .padding(Design.Spacing.md)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: Design.Radius.standard))
    }

    // MARK: - Media Info

    private func mediaInfoSection(_ info: MediaInfo) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.lg) {
            // Title and metadata — Apple card style
            HStack(alignment: .top, spacing: Design.Spacing.lg) {
                if let thumb = info.thumbnailURL {
                    AsyncImage(url: thumb) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: Design.Radius.standard)
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                    .frame(width: 180, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: Design.Radius.standard))
                }

                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Text(info.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .tracking(-0.3)

                    if let uploader = info.uploader {
                        Text(uploader)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: Design.Spacing.md) {
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

            // Advanced options
            DisclosureGroup("Advanced Options") {
                AdvancedOptionsView(args: $advancedArgs)
            }
            .font(.callout)

            // Contextual suggestions
            if !suggestionsForMedia(info).isEmpty {
                VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                    Label("Suggestions", systemImage: "lightbulb.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)

                    ForEach(suggestionsForMedia(info), id: \.self) { suggestion in
                        HStack(spacing: Design.Spacing.sm) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(Design.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.standard))
            }

            // Download button
            HStack {
                Spacer()
                Button(action: startDownload) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showFormatPicker) {
            FormatPickerView(
                mediaInfo: info,
                selectedFormat: $selectedFormat
            )
        }
    }

    // MARK: - Actions

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    let url: URL? = if let data = item as? Data {
                        URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        item as? URL
                    }
                    guard let url, ["http", "https"].contains(url.scheme) else { return }
                    Task { @MainActor in
                        urlText = url.absoluteString
                        fetchInfo()
                    }
                }
                return true
            }
            // File drop support (.txt, .json, .csv)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let fileURL = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let urls = URLParser.extractURLs(fromFileAt: fileURL.path)
                    if !urls.isEmpty {
                        Task { @MainActor in
                            batchMode = true
                            batchURLs = urls
                            batchSelected = Set(urls)
                        }
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    let text: String? = if let s = item as? String { s }
                        else if let d = item as? Data { String(data: d, encoding: .utf8) }
                        else { nil }
                    guard let text else { return }
                    let urls = URLParser.extractURLs(from: text)
                    if urls.count > 1 {
                        Task { @MainActor in
                            batchMode = true
                            batchURLs = urls
                            batchSelected = Set(urls)
                        }
                    } else if let single = urls.first {
                        Task { @MainActor in
                            urlText = single
                            fetchInfo()
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func fetchInfo() {
        guard !urlText.isEmpty else { return }
        fetchTask?.cancel()
        error = nil
        mediaInfo = nil
        isLoading = true

        let url = urlText
        fetchTask = Task {
            do {
                let info = try await manager.fetchMediaInfo(for: url)
                guard !Task.isCancelled else { return }
                mediaInfo = info
            } catch {
                guard !Task.isCancelled else { return }
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
            additionalArgs: advancedArgs,
            thumbnailURL: mediaInfo.thumbnailURL?.absoluteString,
            extractor: mediaInfo.extractor,
            duration: mediaInfo.duration
        )

        // Reset for next download
        urlText = ""
        self.mediaInfo = nil
        selectedFormat = nil
    }

    private func startBatchDownload() {
        for url in batchURLs where batchSelected.contains(url) {
            manager.enqueue(
                url: url,
                title: url,
                formatId: nil,
                additionalArgs: advancedArgs
            )
        }
        // Reset
        urlText = ""
        batchURLs = []
        batchSelected = []
        batchMode = false
    }

    // MARK: - Contextual Suggestions

    private func suggestionsForMedia(_ info: MediaInfo) -> [String] {
        var suggestions: [String] = []

        // AI-friendly suggestions
        if info.duration ?? 0 > 60 {
            suggestions.append("Extract audio as WAV for AI speech-to-text (Whisper)")
        }
        if info.formats.contains(where: { $0.isAudioOnly }) {
            suggestions.append("Download audio only for podcast/music AI analysis")
        }
        if info.extractor.lowercased().contains("youtube") {
            suggestions.append("Auto-generated subtitles available — great for AI text analysis")
            suggestions.append("SponsorBlock can remove sponsor segments automatically")
        }
        if info.duration ?? 0 > 600 {
            suggestions.append("Long video — consider chapter splitting for easier processing")
        }
        if info.formats.count > 20 {
            suggestions.append("\(info.formats.count) formats available — browse all for exact specs")
        }

        return Array(suggestions.prefix(4))
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
                    .accessibilityHidden(true)
                Text(label)
                    .font(.caption.bold())
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 70, minHeight: 50)
            .padding(8)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.quaternary),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) format\(detail.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
