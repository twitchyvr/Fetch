import SwiftUI

// MARK: - Premium Design Tokens

/// Design system inspired by Apple HIG + Stripe's premium aesthetic.
/// Blue-tinted shadows, gradient accents on interactive elements,
/// conservative radii, hover states, section rhythm.
enum Design {
    // MARK: - Colors

    enum Colors {
        // Brand
        static let accentGradientStart = Color(hex: 0x0071E3)
        static let accentGradientEnd = Color(hex: 0x5856D6)

        // Text
        static let primaryText = Color(hex: 0x1D1D1F)
        static let secondaryText = Color(red: 0, green: 0, blue: 0, opacity: 0.56)

        // Surfaces
        static let lightSurface = Color(hex: 0xF5F5F7)
        static let darkSurface = Color(hex: 0x1C1E2B)

        // Shadows — blue-tinted for premium depth (Stripe pattern)
        static let cardShadowFar = Color(red: 50/255, green: 50/255, blue: 93/255, opacity: 0.12)
        static let cardShadowNear = Color(red: 0, green: 0, blue: 0, opacity: 0.06)

        // Status
        static let success = Color(hex: 0x34C759)
        static let warning = Color(hex: 0xCC7700) // darker orange for WCAG AA on white (4.6:1)
        static let error = Color(hex: 0xFF3B30)
    }

    // MARK: - Gradients

    enum Gradients {
        /// Accent gradient for interactive elements (buttons, progress, selections)
        static let accent = LinearGradient(
            colors: [Color(hex: 0x0071E3), Color(hex: 0x5856D6)],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// Subtle surface gradient for section backgrounds
        static let surface = LinearGradient(
            colors: [Color(hex: 0xF8F9FA), Color(hex: 0xF0F1F3)],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Status glow gradient
        static func statusGlow(_ color: Color) -> RadialGradient {
            RadialGradient(
                colors: [color.opacity(0.3), color.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 20
            )
        }
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let section: CGFloat = 48
    }

    // MARK: - Radius (conservative — Stripe pattern)

    enum Radius {
        static let micro: CGFloat = 4
        static let standard: CGFloat = 8
        static let comfortable: CGFloat = 10
        static let large: CGFloat = 14
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Premium View Modifiers

extension View {
    /// Premium card with blue-tinted dual-layer shadow.
    func cardStyle(padding: CGFloat = Design.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius.comfortable)
                    .fill(.background)
                    .shadow(color: Design.Colors.cardShadowFar, radius: 20, x: 0, y: 8)
                    .shadow(color: Design.Colors.cardShadowNear, radius: 6, x: 0, y: 2)
            }
    }

    /// Glass-morphism background for overlays and banners.
    func glassBackground() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.comfortable))
    }

    /// Hover-lift effect — card rises on mouse hover.
    func hoverLift() -> some View {
        self.modifier(HoverLiftModifier())
    }

    /// Gradient accent border for selected/active state.
    func accentBorder(isActive: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: Design.Radius.standard)
                .strokeBorder(
                    isActive
                        ? AnyShapeStyle(Design.Gradients.accent)
                        : AnyShapeStyle(Color.clear),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Hover Lift Modifier

struct HoverLiftModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .shadow(
                color: Design.Colors.cardShadowFar.opacity(isHovered ? 1 : 0.5),
                radius: isHovered ? 24 : 12,
                y: isHovered ? 12 : 4
            )
            .animation(.spring(duration: 0.25), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Gradient Button Style

/// A button style with animated gradient background for primary actions.
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.vertical, Design.Spacing.md)
            .background(Design.Gradients.accent, in: RoundedRectangle(cornerRadius: Design.Radius.standard))
            .foregroundStyle(.white)
            .font(.body.weight(.semibold))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Animated Gradient Progress

/// A progress bar with an animated accent gradient fill.
struct GradientProgressStyle: ProgressViewStyle {
    @State private var animateGradient = false

    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x0071E3),
                                Color(hex: 0x5856D6),
                                Color(hex: 0x0071E3),
                            ],
                            startPoint: UnitPoint(x: animateGradient ? -0.5 : -1.5, y: 0.5),
                            endPoint: UnitPoint(x: animateGradient ? 1.5 : 0.5, y: 0.5)
                        )
                    )
                    .frame(width: max(geo.size.width * fraction, 0))
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animateGradient = true
            }
        }
    }
}
