import SwiftUI

// MARK: - Apple-Inspired Design Tokens

/// Design system aligned with Apple HIG and DESIGN.md principles.
/// Single accent color (Apple Blue), neutral surfaces, tight typography.
enum Design {
    // MARK: - Colors

    enum Colors {
        static let appleBlue = Color(hex: 0x0071E3)
        static let linkBlue = Color(hex: 0x0066CC)
        static let brightBlue = Color(hex: 0x2997FF)

        static let primaryText = Color(hex: 0x1D1D1F)
        static let secondaryText = Color(red: 0, green: 0, blue: 0, opacity: 0.56)
        static let tertiaryText = Color(red: 0, green: 0, blue: 0, opacity: 0.36)

        static let lightSurface = Color(hex: 0xF5F5F7)
        static let darkSurface1 = Color(hex: 0x272729)
        static let darkSurface2 = Color(hex: 0x2A2A2D)

        static let cardShadow = Color(red: 0, green: 0, blue: 0, opacity: 0.12)
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

    // MARK: - Radius

    enum Radius {
        static let micro: CGFloat = 5
        static let standard: CGFloat = 8
        static let comfortable: CGFloat = 12
        static let large: CGFloat = 16
    }

    // MARK: - Elevation

    enum Elevation {
        static let card = ShadowStyle(color: Colors.cardShadow, radius: 15, x: 0, y: 3)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
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

// MARK: - View Modifiers

extension View {
    /// Apple-style card with subtle shadow elevation.
    func cardStyle(padding: CGFloat = Design.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius.comfortable)
                    .fill(.background)
                    .shadow(
                        color: Design.Elevation.card.color,
                        radius: Design.Elevation.card.radius,
                        x: Design.Elevation.card.x,
                        y: Design.Elevation.card.y
                    )
            }
    }

    /// Subtle glass-morphism background for overlays.
    func glassBackground() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.comfortable))
    }
}
