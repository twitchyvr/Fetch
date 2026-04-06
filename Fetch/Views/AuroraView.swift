import SwiftUI

// MARK: - Animated Aurora Background

/// A vivid, animated aurora gradient rendered via Canvas + TimelineView.
/// Five drifting blobs with rich color palette. Adapts to light/dark mode.
struct AuroraView: View {
    @Environment(\.colorScheme) private var colorScheme
    var intensity: Double = 0.15
    var speed: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { context, size in
                drawAurora(context: context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawAurora(context: GraphicsContext, size: CGSize, time: Double) {
        let w = size.width
        let h = size.height
        let dark = colorScheme == .dark

        // Five vivid blobs with complex drift patterns
        let blobs: [(hue: Double, sat: Double, bri: Double, cx: Double, cy: Double, rx: Double, ry: Double)] = [
            // Electric blue — large, slow drift
            (
                dark ? 0.58 : 0.58,
                dark ? 0.9 : 0.5,
                dark ? 0.95 : 0.97,
                w * (0.25 + 0.20 * sin(time * 0.23)),
                h * (0.15 + 0.12 * cos(time * 0.31)),
                w * (0.60 + 0.10 * sin(time * 0.19)),
                h * (0.50 + 0.08 * cos(time * 0.27))
            ),
            // Violet — medium, drifts right
            (
                dark ? 0.76 : 0.78,
                dark ? 0.8 : 0.35,
                dark ? 0.9 : 0.96,
                w * (0.70 + 0.18 * cos(time * 0.29)),
                h * (0.35 + 0.20 * sin(time * 0.21)),
                w * (0.50 + 0.12 * cos(time * 0.33)),
                h * (0.45 + 0.10 * sin(time * 0.25))
            ),
            // Teal — bottom left, pulses
            (
                dark ? 0.48 : 0.45,
                dark ? 0.75 : 0.30,
                dark ? 0.88 : 0.95,
                w * (0.35 + 0.22 * sin(time * 0.17)),
                h * (0.75 + 0.10 * cos(time * 0.23)),
                w * (0.55 + 0.08 * sin(time * 0.29)),
                h * (0.40 + 0.12 * cos(time * 0.19))
            ),
            // Rose/pink — accent, small, fast
            (
                dark ? 0.92 : 0.95,
                dark ? 0.6 : 0.25,
                dark ? 0.9 : 0.97,
                w * (0.60 + 0.25 * cos(time * 0.37)),
                h * (0.55 + 0.15 * sin(time * 0.41)),
                w * (0.35 + 0.10 * sin(time * 0.31)),
                h * (0.30 + 0.08 * cos(time * 0.37))
            ),
            // Gold/amber — warm accent, drifts up
            (
                dark ? 0.12 : 0.10,
                dark ? 0.7 : 0.20,
                dark ? 0.95 : 0.98,
                w * (0.80 + 0.15 * sin(time * 0.19)),
                h * (0.20 + 0.18 * cos(time * 0.27)),
                w * (0.40 + 0.10 * cos(time * 0.23)),
                h * (0.35 + 0.10 * sin(time * 0.31))
            ),
        ]

        for blob in blobs {
            let color = Color(hue: blob.hue, saturation: blob.sat, brightness: blob.bri)
            let rect = CGRect(
                x: blob.cx - blob.rx / 2,
                y: blob.cy - blob.ry / 2,
                width: blob.rx,
                height: blob.ry
            )
            let gradient = Gradient(colors: [
                color.opacity(intensity),
                color.opacity(intensity * 0.4),
                color.opacity(0),
            ])
            let shading = GraphicsContext.Shading.radialGradient(
                gradient,
                center: CGPoint(x: blob.cx, y: blob.cy),
                startRadius: 0,
                endRadius: max(blob.rx, blob.ry) / 2
            )
            context.fill(Ellipse().path(in: rect), with: shading)
        }
    }
}

// MARK: - Shimmer Progress Style

/// An animated shimmer with gradient fill for download progress bars.
struct ShimmerProgressViewStyle: ProgressViewStyle {
    @State private var shimmerOffset: CGFloat = -1.0

    func makeBody(configuration: Configuration) -> some View {
        let fractionCompleted = configuration.fractionCompleted ?? 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)

                // Gradient fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.58, saturation: 0.7, brightness: 0.95),
                                Color(hue: 0.72, saturation: 0.6, brightness: 0.9),
                                Color(hue: 0.58, saturation: 0.7, brightness: 0.95),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * fractionCompleted, 0))
                    .overlay {
                        // Shimmer sweep
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.4), location: 0.45),
                                        .init(color: .white.opacity(0.5), location: 0.5),
                                        .init(color: .white.opacity(0.4), location: 0.55),
                                        .init(color: .clear, location: 1.0),
                                    ],
                                    startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                                    endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                                )
                            )
                            .clipped()
                    }
                    .clipped()
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerOffset = 2.0
            }
        }
    }
}

// MARK: - Pulsing Glow Ring (for active download indicator)

struct PulsingGlow: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(isPulsing ? 0.8 : 0.2), radius: isPulsing ? 8 : 3)
            .scaleEffect(isPulsing ? 1.1 : 0.9)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .accessibilityHidden(true)
    }
}

// MARK: - Animated Gradient Text

struct GradientText: View {
    let text: String
    let font: Font
    @State private var gradientOffset: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Text(text)
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.58, saturation: 0.6, brightness: 0.9),
                            Color(hue: 0.72, saturation: 0.5, brightness: 0.85),
                            Color(hue: 0.58, saturation: 0.6, brightness: 0.9),
                        ],
                        startPoint: UnitPoint(x: sin(t * 0.5) * 0.5, y: 0),
                        endPoint: UnitPoint(x: 1 + sin(t * 0.5) * 0.5, y: 1)
                    )
                )
        }
    }
}

// MARK: - Convenience Modifier

extension View {
    /// Adds a vivid animated aurora as a background behind this view.
    func auroraBackground(intensity: Double = 0.15, speed: Double = 0.6) -> some View {
        self.background {
            AuroraView(intensity: intensity, speed: speed)
        }
    }
}
