import SwiftUI

struct DownloadQueueView: View {
    @Environment(DownloadManager.self) private var manager

    var body: some View {
        Group {
            if manager.activeTasks.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle.dashed",
                    description: Text("Start a download from the New Download tab or paste a URL.")
                )
                .auroraBackground(intensity: 0.15, speed: 0.5)
            } else {
                List {
                    ForEach(manager.activeTasks) { task in
                        DownloadRowView(task: task)
                            .contextMenu {
                                taskContextMenu(task)
                            }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Download Queue")
        .toolbar {
            ToolbarItemGroup {
                if !manager.activeTasks.isEmpty {
                    Button("Clear Finished") {
                        manager.removeCompleted()
                    }
                    .disabled(!manager.activeTasks.contains {
                        $0.status == .completed || $0.status == .cancelled || $0.status == .failed
                    })

                    Button("Cancel All", role: .destructive) {
                        manager.cancelAll()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func taskContextMenu(_ task: DownloadTask) -> some View {
        if task.status == .completed, let path = task.outputPath {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }
            Button("Open") {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
            Divider()
        }

        if task.status == .downloading || task.status == .queued {
            Button("Cancel") { manager.cancel(task) }
        }

        if task.status == .failed {
            Button("Retry") { manager.retry(task) }
        }

        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(task.url, forType: .string)
        }
    }
}
