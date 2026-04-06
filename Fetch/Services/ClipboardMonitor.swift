import AppKit
import Foundation

@Observable
@MainActor
final class ClipboardMonitor {
    private(set) var detectedURL: String?
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    var isEnabled = true
    var onURLDetected: ((String) -> Void)?

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.check()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func dismiss() {
        detectedURL = nil
    }

    private func check() {
        guard isEnabled else { return }

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let content = pasteboard.string(forType: .string) else { return }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeMediaURL(trimmed) else { return }
        guard trimmed != detectedURL else { return }

        detectedURL = trimmed
        onURLDetected?(trimmed)
    }

    private func looksLikeMediaURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              let host = url.host
        else {
            return false
        }

        let knownHosts = [
            "youtube.com", "youtu.be", "www.youtube.com", "m.youtube.com",
            "vimeo.com", "dailymotion.com", "twitch.tv", "www.twitch.tv",
            "soundcloud.com", "bandcamp.com",
            "twitter.com", "x.com",
            "reddit.com", "www.reddit.com",
            "tiktok.com", "www.tiktok.com",
            "instagram.com", "www.instagram.com",
            "facebook.com", "www.facebook.com", "fb.watch",
            "bilibili.com", "www.bilibili.com",
            "nicovideo.jp", "www.nicovideo.jp",
            "crunchyroll.com", "www.crunchyroll.com",
        ]

        return knownHosts.contains(where: { host.hasSuffix($0) })
    }
}
