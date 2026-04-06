import SwiftUI
import SwiftData

@main
struct FetchApp: App {
    @State private var downloadManager = DownloadManager()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(downloadManager)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    downloadManager.cancelAll()
                }
        }
        .modelContainer(for: [Download.self, Preset.self])
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Download") {
                    NSApp.activate()
                }
                .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environment(downloadManager)
        }

        MenuBarExtra("Fetch", systemImage: "arrow.down.circle.fill") {
            MenuBarView()
                .environment(downloadManager)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarView: View {
    @Environment(DownloadManager.self) private var manager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.activeTasks.isEmpty {
                Text("No active downloads")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.activeTasks.prefix(5)) { task in
                    HStack {
                        Text(task.title ?? task.url)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(task.progress))%")
                            .monospacedDigit()
                    }
                }
            }
            Divider()
            Button("Open Fetch") {
                NSApp.activate()
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}
