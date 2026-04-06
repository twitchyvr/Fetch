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
        stop() // Invalidate any existing timer to prevent duplicates
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            // ClipboardMonitor is @MainActor, Timer fires on RunLoop.main,
            // so check() is already on the main actor — no Task wrapper needed.
            MainActor.assumeIsolated {
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

    private static let knownMediaHosts = [
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

    /// Whether the string is a valid http/https URL.
    static func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil
        else { return false }
        return true
    }

    /// Whether the URL is from a well-known media site.
    static func isKnownMediaHost(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              let host = url.host
        else { return false }

        return knownMediaHosts.contains(where: { host.hasSuffix($0) })
    }

    private func looksLikeMediaURL(_ string: String) -> Bool {
        // Clipboard detection scoped to known media hosts to avoid banner spam.
        // Users can paste or drag-drop any URL manually for yt-dlp to try.
        Self.isKnownMediaHost(string)
    }
}
