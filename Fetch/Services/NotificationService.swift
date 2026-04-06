import Foundation
import UserNotifications
import AppKit

/// Manages macOS notifications for download completion and Dock badge updates.
@MainActor
final class NotificationService: NSObject, @unchecked Sendable {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false
    private static let categoryID = "DOWNLOAD_COMPLETE"
    private static let showInFinderActionID = "SHOW_IN_FINDER"
    private static let openFileActionID = "OPEN_FILE"

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        center.delegate = self

        let showInFinder = UNNotificationAction(
            identifier: Self.showInFinderActionID,
            title: "Show in Finder"
        )
        let openFile = UNNotificationAction(
            identifier: Self.openFileActionID,
            title: "Open"
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [openFile, showInFinder],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    /// Request permission lazily — call before first notification, not on launch.
    func requestPermissionIfNeeded() async {
        guard !isAuthorized else { return }
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Download Complete Notification

    func notifyDownloadComplete(title: String, outputPath: String?) async {
        await requestPermissionIfNeeded()
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = Self.categoryID

        if let outputPath {
            content.userInfo = ["outputPath": outputPath]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await center.add(request)
    }

    // MARK: - Dock Badge

    func updateDockBadge(activeCount: Int) {
        if activeCount > 0 {
            NSApp.dockTile.badgeLabel = "\(activeCount)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }
}

// MARK: - Notification Delegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let outputPath = userInfo["outputPath"] as? String

        await MainActor.run {
            guard let outputPath else { return }
            switch actionID {
            case Self.showInFinderActionID, UNNotificationDefaultActionIdentifier:
                NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
            case Self.openFileActionID:
                NSWorkspace.shared.open(URL(fileURLWithPath: outputPath))
            default:
                NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner even when app is foreground
        [.banner, .sound]
    }
}
