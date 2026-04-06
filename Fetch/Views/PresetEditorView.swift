import SwiftUI
import SwiftData

struct PresetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Preset.dateCreated) private var presets: [Preset]

    @State private var selectedPreset: Preset?
    @State private var showingNew = false

    var body: some View {
        HSplitView {
            // Preset list
            List(selection: $selectedPreset) {
                Section("Built-in") {
                    ForEach(Preset.builtIn, id: \.name) { preset in
                        Label(preset.name, systemImage: "star")
                            .tag(preset)
                    }
                }

                if !presets.isEmpty {
                    Section("Custom") {
                        ForEach(presets) { preset in
                            Label(preset.name, systemImage: "slider.horizontal.3")
                                .tag(preset)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        modelContext.delete(preset)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)

            // Detail
            if let preset = selectedPreset {
                PresetDetailView(preset: preset)
            } else {
                ContentUnavailableView(
                    "Select a Preset",
                    systemImage: "slider.horizontal.3",
                    description: Text("Choose a preset to view or edit its settings.")
                )
            }
        }
        .navigationTitle("Presets")
        .toolbar {
            ToolbarItem {
                Button {
                    let preset = Preset(name: "New Preset")
                    modelContext.insert(preset)
                    selectedPreset = preset
                } label: {
                    Label("New Preset", systemImage: "plus")
                }
            }
        }
    }
}

struct PresetDetailView: View {
    @Bindable var preset: Preset

    var body: some View {
        Form {
            Section("General") {
                TextField("Name", text: $preset.name)

                TextField("Output Directory", text: $preset.outputDirectory)
                    .help("Use ~ for home directory. e.g., ~/Downloads/Fetch")

                TextField("Filename Template", text: $preset.outputTemplate)
                    .font(.body.monospaced())
                    .help("yt-dlp output template. e.g., %(title)s.%(ext)s")
            }

            Section("Format") {
                TextField("Format Selection", text: $preset.formatSelection)
                    .font(.body.monospaced())
                    .help("yt-dlp format string. e.g., bestvideo[ext=mp4]+bestaudio[ext=m4a]/best")

                Picker("Quality", selection: $preset.preferredQuality) {
                    Text("Best").tag("best")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                    Text("480p").tag("480p")
                    Text("Audio Only").tag("audio")
                }
            }

            Section("Embedding") {
                Toggle("Embed Thumbnail", isOn: $preset.embedThumbnail)
                Toggle("Embed Subtitles", isOn: $preset.embedSubtitles)
                Toggle("Embed Metadata", isOn: $preset.embedMetadata)
            }

            Section("Advanced") {
                TextField("Extra Arguments", text: $preset.extraArguments, axis: .vertical)
                    .font(.body.monospaced())
                    .lineLimit(3...6)
                    .help("Additional yt-dlp arguments, space-separated")
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generated command:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(previewCommand)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var previewCommand: String {
        var parts = ["yt-dlp"]
        parts += preset.asArguments()
        parts += ["-o", "\(preset.outputDirectory)/\(preset.outputTemplate)"]
        parts += ["<URL>"]
        return parts.joined(separator: " ")
    }
}
