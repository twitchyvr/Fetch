import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct FetchApp: App {
    @State private var downloadManager = DownloadManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @Environment(\.openWindow) private var openWindow

    init() {
        NotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(downloadManager)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    downloadManager.cancelAll()
                    cleanupSpotlightIndex()
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding, onDismiss: {
                    hasCompletedOnboarding = true
                }) {
                    OnboardingView(isPresented: $showOnboarding)
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
            CommandGroup(replacing: .help) {
                Button("Welcome to Fetch...") {
                    showOnboarding = true
                }
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

    /// Remove Spotlight index entries whose files no longer exist on disk
    private func cleanupSpotlightIndex() {
        let outputDir = downloadManager.defaultOutputDirectory
        let expanded = NSString(string: outputDir).expandingTildeInPath
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(atPath: expanded) else { return }

        var validPaths: [String] = []
        while let file = enumerator.nextObject() as? String {
            validPaths.append((expanded as NSString).appendingPathComponent(file))
        }

        SpotlightService.shared.removeStaleItems(validPaths: validPaths)
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
