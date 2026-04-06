import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection
    let activeCount: Int
    @Environment(DownloadManager.self) private var manager

    var body: some View {
        List(selection: $selection) {
            Section("Downloads") {
                Label(SidebarSection.newDownload.rawValue, systemImage: SidebarSection.newDownload.icon)
                    .tag(SidebarSection.newDownload)

                HStack {
                    Label(SidebarSection.queue.rawValue, systemImage: SidebarSection.queue.icon)
                    Spacer()
                    if activeCount > 0 {
                        Text("\(activeCount)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                .tag(SidebarSection.queue)

                Label(SidebarSection.history.rawValue, systemImage: SidebarSection.history.icon)
                    .tag(SidebarSection.history)
            }

            Section("Configuration") {
                Label(SidebarSection.presets.rawValue, systemImage: SidebarSection.presets.icon)
                    .tag(SidebarSection.presets)
            }

            Section {
                VersionFooter()
            }
        }
        .listStyle(.sidebar)
    }
}

struct VersionFooter: View {
    @Environment(DownloadManager.self) private var manager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.isCheckingVersion {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Checking yt-dlp...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let version = manager.ytdlpVersion {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                    Text("yt-dlp \(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if manager.updateAvailable {
                    Button("Update Available") {
                        Task { try? await manager.updateYTDLP() }
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text("yt-dlp not found")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
