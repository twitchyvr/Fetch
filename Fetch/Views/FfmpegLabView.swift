import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// FFmpeg Lab — a post-processing workspace for any media file.
struct FfmpegLabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Download.dateCreated, order: .reverse) private var downloads: [Download]

    @State private var selectedFile: String?
    @State private var probeResult: MediaProbe?
    @State private var isProbing = false
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var error: String?
    @State private var outputFormat = "mp4"
    @State private var activeTab: LabTab = .remux

    // Operation states
    @State private var extractAudio = false
    @State private var audioFormat = "mp3"
    @State private var audioQuality = "0"
    @State private var targetResolution = ""
    @State private var videoCRF = "23"
    @State private var videoCodec = "libx264"
    @State private var normalizeAudio = false
    @State private var trimStart = ""
    @State private var trimEnd = ""
    @State private var extractFrames = false
    @State private var frameInterval = "1"
    @State private var burnSubtitles = false
    @State private var stripMetadata = false
    @State private var customArgs = ""

    private let service = FfmpegService()

    enum LabTab: String, CaseIterable, Identifiable {
        case remux = "Remux"
        case audio = "Audio"
        case video = "Video"
        case filters = "Filters"
        case trim = "Trim"
        case extract = "Extract"
        case metadata = "Metadata"
        case ai = "AI Presets"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .remux: "arrow.triangle.swap"
            case .audio: "waveform"
            case .video: "film"
            case .filters: "camera.filters"
            case .trim: "scissors"
            case .extract: "photo.on.rectangle"
            case .metadata: "tag"
            case .ai: "cpu"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // File selector
            fileSelector

            if let probe = probeResult {
                Divider()

                // File info summary
                fileInfoBar(probe)

                Divider()

                // Operation tabs
                tabBar

                // Tab content
                ScrollView {
                    Group {
                        switch activeTab {
                        case .remux: remuxPanel
                        case .audio: audioPanel
                        case .video: videoPanel
                        case .filters: filtersPanel
                        case .trim: trimPanel
                        case .extract: extractPanel
                        case .metadata: metadataPanel
                        case .ai: aiPresetsPanel
                        }
                    }
                    .padding()
                }

                Divider()

                // Command preview + Process button
                bottomBar
            } else if isProbing {
                Spacer()
                ProgressView("Analyzing file...")
                Spacer()
            } else {
                Spacer()
                ContentUnavailableView(
                    "FFmpeg Lab",
                    systemImage: "flask",
                    description: Text("Select a file from your Library or drop one here to start processing.")
                )
                Spacer()
            }
        }
        .navigationTitle("FFmpeg Lab")
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
    }

    // MARK: - File Selector

    private var fileSelector: some View {
        HStack(spacing: Design.Spacing.md) {
            Image(systemName: "doc.badge.gearshape")
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            if let file = selectedFile {
                VStack(alignment: .leading, spacing: 1) {
                    Text(URL(fileURLWithPath: file).lastPathComponent)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(file)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text("No file selected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu("Select File") {
                Button("Browse...") { browseFile() }
                Divider()
                if !downloads.isEmpty {
                    Text("From Library").font(.caption)
                    ForEach(downloads.prefix(10)) { download in
                        if let path = download.outputPath {
                            Button(download.title) { selectFile(path) }
                        }
                    }
                }
            }
            .controlSize(.small)
        }
        .padding()
    }

    // MARK: - File Info Bar

    private func fileInfoBar(_ probe: MediaProbe) -> some View {
        HStack(spacing: Design.Spacing.lg) {
            if let fmt = probe.formatName {
                Label(fmt, systemImage: "doc")
            }
            if let dur = probe.duration {
                Label(DurationFormatter.format(dur), systemImage: "clock")
            }
            if let size = probe.fileSize {
                Label(ByteCountFormatter.string(fromByteCount: size, countStyle: .file), systemImage: "internaldrive")
            }
            ForEach(probe.videoStreams) { stream in
                if let res = stream.resolution {
                    Label("\(res) \(stream.codecName)", systemImage: "film")
                }
            }
            ForEach(probe.audioStreams) { stream in
                Label("\(stream.codecName) \(stream.channels ?? 0)ch", systemImage: "waveform")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, Design.Spacing.sm)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(LabTab.allCases) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(activeTab == tab ? Color.accentColor.opacity(0.15) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Design.Spacing.xs)
        }
    }

    // MARK: - Operation Panels

    private var remuxPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Change container without re-encoding (instant)")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Output Format", selection: $outputFormat) {
                Text("MP4").tag("mp4")
                Text("MKV").tag("mkv")
                Text("WebM").tag("webm")
                Text("MOV").tag("mov")
                Text("AVI").tag("avi")
                Text("TS").tag("ts")
                Text("OGG").tag("ogg")
            }
            .pickerStyle(.segmented)
        }
    }

    private var audioPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Toggle("Extract audio only", isOn: $extractAudio)
            Picker("Audio Format", selection: $audioFormat) {
                Text("MP3").tag("mp3"); Text("AAC").tag("aac")
                Text("FLAC").tag("flac"); Text("WAV").tag("wav")
                Text("Opus").tag("opus"); Text("Vorbis").tag("vorbis")
                Text("ALAC").tag("alac")
            }
            HStack {
                Text("Quality (0=best, 9=worst)")
                Picker("", selection: $audioQuality) {
                    ForEach(0..<10) { i in Text("\(i)").tag("\(i)") }
                }
                .frame(width: 60)
            }
            Toggle("Normalize loudness (-16 LUFS)", isOn: $normalizeAudio)
        }
    }

    private var videoPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Picker("Codec", selection: $videoCodec) {
                Text("H.264").tag("libx264")
                Text("H.265/HEVC").tag("libx265")
                Text("VP9").tag("libvpx-vp9")
                Text("AV1").tag("libaom-av1")
            }
            HStack {
                Text("CRF (quality: 0=lossless, 51=worst)")
                TextField("23", text: $videoCRF)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Resolution")
                TextField("e.g. 1920x1080", text: $targetResolution)
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
            }
        }
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Toggle("Burn-in subtitles (hardcode)", isOn: $burnSubtitles)
            Toggle("Normalize audio volume", isOn: $normalizeAudio)
            Text("Custom ffmpeg filter string:")
                .font(.caption).foregroundStyle(.secondary)
            TextField("-vf scale=1280:720 -af loudnorm", text: $customArgs)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
        }
    }

    private var trimPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Extract a segment of the file")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Start:")
                TextField("00:00:00", text: $trimStart)
                    .frame(width: 100).textFieldStyle(.roundedBorder).font(.caption.monospaced())
                Text("End:")
                TextField("00:05:00", text: $trimEnd)
                    .frame(width: 100).textFieldStyle(.roundedBorder).font(.caption.monospaced())
            }
        }
    }

    private var extractPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Toggle("Extract frames as images", isOn: $extractFrames)
            if extractFrames {
                HStack {
                    Text("Frame interval (seconds):")
                    TextField("1", text: $frameInterval)
                        .frame(width: 50).textFieldStyle(.roundedBorder)
                }
            }
            Text("Extracted frames saved alongside the source file.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Toggle("Strip all metadata", isOn: $stripMetadata)
            Text("Removes title, artist, comments, GPS, and other embedded metadata.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var aiPresetsPanel: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.lg) {
            Text("One-click presets optimized for AI workflows")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(aiPresets, id: \.name) { preset in
                Button {
                    applyAIPreset(preset)
                } label: {
                    HStack(spacing: Design.Spacing.md) {
                        Image(systemName: preset.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name).font(.callout.weight(.semibold))
                            Text(preset.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(preset.outputInfo).font(.caption.monospaced()).foregroundStyle(.tertiary)
                    }
                    .padding(Design.Spacing.md)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Command preview
            Text(buildCommandPreview())
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if isProcessing {
                ProgressView(value: progress, total: 100)
                    .frame(width: 100)
            }

            Button(isProcessing ? "Processing..." : "Process") {
                processFile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedFile == nil || isProcessing)
        }
        .padding()
    }

    // MARK: - Actions

    private func browseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .audio, .mpeg4Movie, .mp3, .wav, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            selectFile(url.path)
        }
    }

    private func selectFile(_ path: String) {
        selectedFile = path
        probeResult = nil
        isProbing = true
        Task {
            do {
                probeResult = try await service.probe(filePath: path)
            } catch {
                self.error = error.localizedDescription
            }
            isProbing = false
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }
                    Task { @MainActor in selectFile(url.path) }
                }
                return true
            }
        }
        return false
    }

    private func processFile() {
        guard let input = selectedFile else { return }
        isProcessing = true
        progress = 0

        let args = buildArgs()
        let ext = activeTab == .remux ? outputFormat : (extractAudio ? audioFormat : outputFormat)
        let inputURL = URL(fileURLWithPath: input)
        let outputName = inputURL.deletingPathExtension().lastPathComponent + "_processed.\(ext)"
        let output = inputURL.deletingLastPathComponent().appendingPathComponent(outputName).path

        Task {
            do {
                try await service.run(inputPath: input, outputPath: output, arguments: args) { pct in
                    Task { @MainActor in progress = pct }
                }
                // Open in Finder
                NSWorkspace.shared.selectFile(output, inFileViewerRootedAtPath: "")
            } catch {
                self.error = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func buildArgs() -> [String] {
        var args: [String] = []

        switch activeTab {
        case .remux:
            args += ["-c", "copy"]

        case .audio:
            if extractAudio {
                args += ["-vn"]
            }
            args += ["-c:a", audioCodecFor(audioFormat)]
            if normalizeAudio {
                args += ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"]
            }

        case .video:
            args += ["-c:v", videoCodec, "-crf", videoCRF]
            if !targetResolution.isEmpty {
                args += ["-vf", "scale=\(targetResolution.replacingOccurrences(of: "x", with: ":"))"]
            }

        case .filters:
            if burnSubtitles { args += ["-vf", "subtitles='\(selectedFile ?? "")' "] }
            if normalizeAudio { args += ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"] }
            if !customArgs.isEmpty {
                args += customArgs.components(separatedBy: " ")
            }

        case .trim:
            if !trimStart.isEmpty { args += ["-ss", trimStart] }
            if !trimEnd.isEmpty { args += ["-to", trimEnd] }
            args += ["-c", "copy"]

        case .extract:
            if extractFrames {
                args += ["-vf", "fps=1/\(frameInterval)"]
                // Output will be frame pattern
            }

        case .metadata:
            if stripMetadata {
                args += ["-map_metadata", "-1"]
            }
            args += ["-c", "copy"]

        case .ai:
            break // Handled by preset application
        }

        return args
    }

    private func buildCommandPreview() -> String {
        guard let input = selectedFile else { return "ffmpeg ..." }
        let args = buildArgs()
        let inputName = URL(fileURLWithPath: input).lastPathComponent
        return "ffmpeg -i \"\(inputName)\" \(args.joined(separator: " ")) output.\(outputFormat)"
    }

    private func audioCodecFor(_ format: String) -> String {
        switch format {
        case "mp3": "libmp3lame"
        case "aac": "aac"
        case "flac": "flac"
        case "wav": "pcm_s16le"
        case "opus": "libopus"
        case "vorbis": "libvorbis"
        case "alac": "alac"
        default: "copy"
        }
    }

    // MARK: - AI Presets

    struct AIPreset {
        let name: String
        let description: String
        let icon: String
        let outputInfo: String
        let apply: () -> Void
    }

    private var aiPresets: [AIPreset] {
        [
            AIPreset(name: "Whisper-Ready Audio", description: "WAV 16kHz mono — optimal for OpenAI Whisper and speech-to-text", icon: "mic", outputInfo: "WAV 16kHz 1ch") {
                extractAudio = true; audioFormat = "wav"; customArgs = "-ar 16000 -ac 1"
                activeTab = .audio
            },
            AIPreset(name: "Vision AI Frames", description: "Extract key frames at 1fps as JPEG — for image recognition models", icon: "eye", outputInfo: "JPEG 1fps") {
                extractFrames = true; frameInterval = "1"
                activeTab = .extract
            },
            AIPreset(name: "Podcast Audio", description: "MP3 128k mono — optimized for spoken word and podcast apps", icon: "mic.badge.plus", outputInfo: "MP3 128k 1ch") {
                extractAudio = true; audioFormat = "mp3"; normalizeAudio = true
                activeTab = .audio
            },
            AIPreset(name: "Music Lossless", description: "FLAC — lossless audio for music analysis and archival", icon: "music.note", outputInfo: "FLAC lossless") {
                extractAudio = true; audioFormat = "flac"
                activeTab = .audio
            },
            AIPreset(name: "Web-Optimized Video", description: "H.264 MP4 720p CRF 23 — fast streaming, small file", icon: "globe", outputInfo: "MP4 720p") {
                videoCodec = "libx264"; videoCRF = "23"; targetResolution = "1280x720"; outputFormat = "mp4"
                activeTab = .video
            },
        ]
    }

    private func applyAIPreset(_ preset: AIPreset) {
        preset.apply()
    }
}
