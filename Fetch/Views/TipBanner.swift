import SwiftUI

// MARK: - Tip Banner

/// A rotating tip banner for empty states that cycles through helpful hints.
/// Uses declarative .onReceive(Timer.publish) to tie timer lifecycle to the view.
struct TipBanner: View {
    @State private var currentTipIndex = 0

    private static let tips: [String] = [
        "Did you know? Fetch supports 1,800+ sites via yt-dlp.",
        "Tip: Use Cmd+Shift+V to paste and fetch in one step.",
        "Try SponsorBlock to automatically skip sponsor segments.",
        "Download subtitles for AI text analysis with Advanced Options.",
        "Save your favorite settings as presets for one-click downloads.",
        "Drag and drop URLs directly into Fetch to start downloading.",
        "Fetch auto-detects URLs copied to your clipboard.",
    ]

    private let timer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.callout)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            Text(Self.tips[currentTipIndex])
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .id(currentTipIndex)
                .transition(.opacity)
        }
        .padding(.horizontal, Design.Spacing.lg)
        .padding(.vertical, Design.Spacing.md)
        .glassBackground()
        .animation(.easeInOut(duration: 0.5), value: currentTipIndex)
        .onReceive(timer) { _ in
            currentTipIndex = (currentTipIndex + 1) % Self.tips.count
        }
        .accessibilityElement(children: .combine)
    }
}
