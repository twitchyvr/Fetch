import SwiftUI

// MARK: - Animated Aurora Background

/// A subtle, animated aurora gradient rendered via Canvas + TimelineView.
/// Adapts to light/dark mode. Designed to sit behind content as a background layer.
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

        // Three organic blobs that drift and pulse
        let blobs: [(color: Color, cx: Double, cy: Double, rx: Double, ry: Double)] = [
            (
                auroraColor1,
                w * (0.3 + 0.2 * sin(time * 0.3)),
                h * (0.2 + 0.15 * cos(time * 0.4)),
                w * (0.5 + 0.1 * sin(time * 0.5)),
                h * (0.4 + 0.1 * cos(time * 0.35))
            ),
            (
                auroraColor2,
                w * (0.7 + 0.15 * cos(time * 0.25)),
                h * (0.6 + 0.2 * sin(time * 0.3)),
                w * (0.45 + 0.15 * cos(time * 0.4)),
                h * (0.5 + 0.1 * sin(time * 0.45))
            ),
            (
                auroraColor3,
                w * (0.5 + 0.25 * sin(time * 0.2)),
                h * (0.8 + 0.1 * cos(time * 0.35)),
                w * (0.6 + 0.1 * sin(time * 0.3)),
                h * (0.35 + 0.1 * cos(time * 0.5))
            ),
        ]

        for blob in blobs {
            let rect = CGRect(
                x: blob.cx - blob.rx / 2,
                y: blob.cy - blob.ry / 2,
                width: blob.rx,
                height: blob.ry
            )
            let gradient = Gradient(colors: [
                blob.color.opacity(intensity),
                blob.color.opacity(0),
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

    private var auroraColor1: Color {
        colorScheme == .dark
            ? Color(hue: 0.55, saturation: 0.8, brightness: 0.9)  // cyan
            : Color(hue: 0.58, saturation: 0.4, brightness: 0.95) // light blue
    }

    private var auroraColor2: Color {
        colorScheme == .dark
            ? Color(hue: 0.75, saturation: 0.7, brightness: 0.85) // purple
            : Color(hue: 0.78, saturation: 0.3, brightness: 0.95) // light violet
    }

    private var auroraColor3: Color {
        colorScheme == .dark
            ? Color(hue: 0.45, saturation: 0.6, brightness: 0.8)  // teal
            : Color(hue: 0.42, saturation: 0.25, brightness: 0.95) // light teal
    }
}

// MARK: - Shimmer Progress Style

/// An animated shimmer overlay for progress bars.
struct ShimmerProgressViewStyle: ProgressViewStyle {
    @State private var shimmerOffset: CGFloat = -1.0

    func makeBody(configuration: Configuration) -> some View {
        let fractionCompleted = configuration.fractionCompleted ?? 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * fractionCompleted)
                    .overlay {
                        // Shimmer
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.3), location: 0.5),
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
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 2.0
            }
        }
    }
}

// MARK: - Convenience Modifier

extension View {
    /// Adds a subtle animated aurora as a background behind this view.
    func auroraBackground(intensity: Double = 0.12, speed: Double = 0.6) -> some View {
        self.background {
            AuroraView(intensity: intensity, speed: speed)
        }
    }
}
