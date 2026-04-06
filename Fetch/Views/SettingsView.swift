import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultOutputDirectory") private var outputDirectory = "~/Downloads/Fetch"
    @AppStorage("maxConcurrentDownloads") private var maxConcurrent = 3
    @AppStorage("clipboardMonitoring") private var clipboardMonitoring = true
    @AppStorage("embedThumbnail") private var embedThumbnail = true
    @AppStorage("embedMetadata") private var embedMetadata = true
    @AppStorage("defaultFormat") private var defaultFormat = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"

    @Environment(DownloadManager.self) private var manager

    @State private var ytdlpPath = ""
    @State private var extractorCount = 0

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            downloadTab
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }

            advancedTab
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 500, height: 380)
        .task {
            ytdlpPath = (try? await manager.findBinaryPath()) ?? "Not found"
            extractorCount = (try? await manager.listExtractors().count) ?? 0
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                HStack {
                    TextField("Download Location", text: $outputDirectory)
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            outputDirectory = url.path
                        }
                    }
                }

                Stepper("Concurrent Downloads: \(maxConcurrent)", value: $maxConcurrent, in: 1...10)
            }

            Section {
                Toggle("Monitor Clipboard for URLs", isOn: $clipboardMonitoring)
                    .help("Automatically detect when you copy a supported URL")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Downloads

    private var downloadTab: some View {
        Form {
            Section("Default Format") {
                TextField("Format String", text: $defaultFormat)
                    .font(.body.monospaced())
                    .help("yt-dlp format selection string")

                Text("Common presets:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Best") { defaultFormat = "bestvideo+bestaudio/best" }
                    Button("1080p MP4") { defaultFormat = "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]" }
                    Button("720p") { defaultFormat = "bestvideo[height<=720]+bestaudio/best[height<=720]" }
                    Button("Audio") { defaultFormat = "bestaudio" }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Section("Defaults") {
                Toggle("Embed Thumbnail", isOn: $embedThumbnail)
                Toggle("Embed Metadata", isOn: $embedMetadata)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("yt-dlp") {
                LabeledContent("Binary Path") {
                    Text(ytdlpPath)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                LabeledContent("Version") {
                    HStack {
                        Text(manager.ytdlpVersion ?? "Unknown")
                            .font(.caption.monospaced())
                        if manager.updateAvailable {
                            Button("Update") {
                                Task { try? await manager.updateYTDLP() }
                            }
                            .controlSize(.small)
                        }
                    }
                }

                LabeledContent("Supported Sites") {
                    Text("\(extractorCount)")
                }
            }

            Section {
                Button("Check for yt-dlp Updates") {
                    Task { await manager.checkVersion() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
