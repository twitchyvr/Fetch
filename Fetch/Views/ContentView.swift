import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: SidebarSection = .newDownload
    @State private var clipboardMonitor = ClipboardMonitor()
    @State private var clipboardURL: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection, activeCount: manager.activeDownloadCount)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            Group {
                switch selectedSection {
                case .newDownload:
                    NewDownloadView(initialURL: clipboardURL)
                case .queue:
                    DownloadQueueView()
                case .history:
                    HistoryView()
                case .presets:
                    PresetEditorView()
                }
            }
            .frame(minWidth: 500)
            .animation(.smooth(duration: 0.25), value: selectedSection)
        }
        .frame(minWidth: 760, minHeight: 480)
        .onAppear {
            manager.modelContext = modelContext
            clipboardMonitor.onURLDetected = { url in
                clipboardURL = url
                selectedSection = .newDownload
            }
            clipboardMonitor.start()
            Task { await manager.checkVersion() }
        }
        .onDisappear {
            clipboardMonitor.stop()
        }
        .overlay(alignment: .bottom) {
            if let url = clipboardMonitor.detectedURL, selectedSection != .newDownload {
                ClipboardBanner(url: url) {
                    clipboardURL = url
                    selectedSection = .newDownload
                    clipboardMonitor.dismiss()
                } onDismiss: {
                    clipboardMonitor.dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: clipboardMonitor.detectedURL)
            }
        }
    }
}

// MARK: - Clipboard Banner

struct ClipboardBanner: View {
    let url: String
    let onUse: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("URL detected in clipboard")
                    .font(.caption.bold())
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Download", action: onUse)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss")
        }
        .padding(Design.Spacing.md)
        .glassBackground()
        .shadow(color: Design.Colors.cardShadow, radius: 10, y: 4)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

enum SidebarSection: String, Hashable, CaseIterable {
    case newDownload = "New Download"
    case queue = "Queue"
    case history = "History"
    case presets = "Presets"

    var icon: String {
        switch self {
        case .newDownload: "plus.circle"
        case .queue: "arrow.down.circle"
        case .history: "clock"
        case .presets: "slider.horizontal.3"
        }
    }
}
