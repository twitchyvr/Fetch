import SwiftUI
import SwiftData

struct PresetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Preset.dateCreated) private var presets: [Preset]

    @State private var selectedPreset: Preset?

    var body: some View {
        HSplitView {
            // Preset list with rich rows
            List(selection: $selectedPreset) {
                Section("Built-in") {
                    ForEach(Preset.builtIn, id: \.name) { preset in
                        PresetRowView(name: preset.name, icon: iconFor(preset), quality: preset.preferredQuality)
                            .tag(preset)
                    }
                }

                Section("AI & Research") {
                    ForEach(Preset.aiBuiltIn, id: \.name) { preset in
                        PresetRowView(name: preset.name, icon: "cpu", quality: preset.preferredQuality, isAI: true)
                            .tag(preset)
                    }
                }

                if !presets.isEmpty {
                    Section("Custom") {
                        ForEach(presets) { preset in
                            PresetRowView(name: preset.name, icon: "slider.horizontal.3", quality: preset.preferredQuality)
                                .tag(preset)
                                .contextMenu {
                                    Button("Duplicate") {
                                        let copy = Preset(name: "\(preset.name) Copy",
                                                          formatSelection: preset.formatSelection,
                                                          outputTemplate: preset.outputTemplate,
                                                          outputDirectory: preset.outputDirectory,
                                                          embedThumbnail: preset.embedThumbnail,
                                                          embedSubtitles: preset.embedSubtitles,
                                                          embedMetadata: preset.embedMetadata,
                                                          preferredQuality: preset.preferredQuality,
                                                          extraArguments: preset.extraArguments)
                                        modelContext.insert(copy)
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        modelContext.delete(preset)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220, minHeight: 400)

            // Detail
            if let preset = selectedPreset {
                PresetDetailView(preset: preset)
            } else {
                VStack(spacing: Design.Spacing.lg) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                    Text("Select a Preset")
                        .font(.title2.weight(.semibold))
                    Text("Choose a preset to view its settings,\nor create a new one with the + button.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Divider().frame(maxWidth: 200)

                    VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                        Label("\(Preset.builtIn.count) built-in presets", systemImage: "star")
                        Label("\(Preset.aiBuiltIn.count) AI & research presets", systemImage: "cpu")
                        Label("\(presets.count) custom presets", systemImage: "slider.horizontal.3")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func iconFor(_ preset: Preset) -> String {
        switch preset.preferredQuality {
        case "audio": "music.note"
        case "1080p", "720p", "480p": "film"
        default: "star.fill"
        }
    }
}

// MARK: - Preset Row

struct PresetRowView: View {
    let name: String
    let icon: String
    let quality: String
    var isAI: Bool = false

    var body: some View {
        HStack(spacing: Design.Spacing.sm) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(isAI ? Color.purple : Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.callout)
                    .lineLimit(1)
                Text(quality)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preset Detail

struct PresetDetailView: View {
    @Bindable var preset: Preset
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.xl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Preset Name", text: $preset.name)
                            .font(.title3.weight(.semibold))
                            .textFieldStyle(.plain)
                        Text(preset.preferredQuality.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    Spacer()
                }

                // Command Preview Card
                VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                    HStack {
                        Label("Command Preview", systemImage: "terminal")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(previewCommand, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                    Text(previewCommand)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(Design.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Design.Radius.standard))
                }

                Divider()

                // Settings
                settingsSection("Output", icon: "folder") {
                    LabeledField("Directory", text: $preset.outputDirectory, help: "~/Downloads/Fetch")
                    LabeledField("Filename Template", text: $preset.outputTemplate, mono: true, help: "%(title)s.%(ext)s")
                }

                settingsSection("Format", icon: "film") {
                    LabeledField("Format String", text: $preset.formatSelection, mono: true)
                    Picker("Quality", selection: $preset.preferredQuality) {
                        Text("Best").tag("best")
                        Text("1080p").tag("1080p")
                        Text("720p").tag("720p")
                        Text("480p").tag("480p")
                        Text("Audio Only").tag("audio")
                    }
                    .pickerStyle(.segmented)
                }

                settingsSection("Embedding", icon: "paperclip") {
                    Toggle("Embed Thumbnail", isOn: $preset.embedThumbnail)
                    Toggle("Embed Subtitles", isOn: $preset.embedSubtitles)
                    Toggle("Embed Metadata", isOn: $preset.embedMetadata)
                }

                settingsSection("Extra Arguments", icon: "terminal") {
                    TextEditor(text: $preset.extraArguments)
                        .font(.body.monospaced())
                        .frame(minHeight: 60, maxHeight: 120)
                        .border(Color.secondary.opacity(0.2))
                }
            }
            .padding(Design.Spacing.xl)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Label(title, systemImage: icon)
                .font(.callout.bold())
            content()
        }
    }

    private var previewCommand: String {
        var parts = ["yt-dlp"]
        parts += preset.asArguments()
        parts += ["-o", "\(preset.outputDirectory)/\(preset.outputTemplate)"]
        parts += ["<URL>"]
        return parts.joined(separator: " ")
    }
}

// MARK: - Labeled Field Helper

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var mono: Bool = false
    var help: String? = nil

    init(_ label: String, text: Binding<String>, mono: Bool = false, help: String? = nil) {
        self.label = label
        self._text = text
        self.mono = mono
        self.help = help
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(help ?? "", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(mono ? .body.monospaced() : .body)
        }
    }
}
