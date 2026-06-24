import SwiftUI

/// The single design-token layer. Every colour, radius, font, and motion constant
/// routes through here so the v1 SwiftUI/SF-Symbols look can be swapped for custom
/// or generated art (the fast-follow) by editing tokens, not views.
enum Theme {

    // MARK: Palette (bright but restrained, §12). Light-first; dark via semantic colors.
    enum Color {
        static let bg = SwiftUI.Color(red: 0.97, green: 0.98, blue: 1.0)
        static let surface = SwiftUI.Color.white
        static let ink = SwiftUI.Color(red: 0.12, green: 0.14, blue: 0.22)
        static let inkSoft = SwiftUI.Color(red: 0.42, green: 0.45, blue: 0.55)

        static let primary = SwiftUI.Color(red: 0.30, green: 0.45, blue: 0.98)   // friendly blue
        static let accent = SwiftUI.Color(red: 1.0, green: 0.72, blue: 0.20)     // warm gold (XP)
        static let correct = SwiftUI.Color(red: 0.20, green: 0.78, blue: 0.50)
        static let gentle = SwiftUI.Color(red: 0.62, green: 0.66, blue: 0.78)    // neutral wrong-answer

        /// Fact display-state colours for the mastery grid (§8). Always paired with a
        /// shape/badge so state never relies on colour alone (accessibility).
        static func state(_ s: FactDisplayState) -> SwiftUI.Color {
            switch s {
            case .notStarted: return SwiftUI.Color(red: 0.90, green: 0.92, blue: 0.96)
            case .learning:   return SwiftUI.Color(red: 0.55, green: 0.70, blue: 1.0)
            case .fluent:     return SwiftUI.Color(red: 0.45, green: 0.78, blue: 0.95)
            case .mastered:   return correct
            }
        }
    }

    // MARK: Typography — SF Rounded; the numeral is the hero (§12).
    enum Font {
        static func display(_ size: CGFloat) -> SwiftUI.Font { .system(size: size, weight: .heavy, design: .rounded) }
        static func number(_ size: CGFloat) -> SwiftUI.Font { .system(size: size, weight: .bold, design: .rounded) }
        static func body(_ size: CGFloat = 18) -> SwiftUI.Font { .system(size: size, weight: .medium, design: .rounded) }
        static func label(_ size: CGFloat = 15) -> SwiftUI.Font { .system(size: size, weight: .semibold, design: .rounded) }
    }

    enum Metric {
        static let corner: CGFloat = 22
        static let cornerSmall: CGFloat = 14
        static let gap: CGFloat = 16
        static let pad: CGFloat = 24
    }

    // MARK: Motion — calm in the loop, lavish at milestones.
    enum Motion {
        /// In-loop feedback: fast and snappy (≤200ms) so it never slows his pace.
        static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.7)
        static let quick = Animation.easeOut(duration: 0.18)
        /// Milestone beats: bigger, bouncier.
        static let celebrate = Animation.spring(response: 0.5, dampingFraction: 0.6)

        /// On-screen duration for each celebration tier, in seconds.
        static func duration(_ tier: CelebrationTier) -> Double {
            switch tier {
            case .t0: return 0.2
            case .t1: return 0.8
            case .t2: return 1.8
            case .t3: return 2.6
            case .t4: return 4.0
            }
        }
    }
}

extension View {
    /// Standard card surface used across the app.
    func cardSurface() -> some View {
        self
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

/// Tactile press feedback for large kid-facing buttons (HIG: clear affordance +
/// immediate response). Shrinks slightly on press; respects Reduced Motion.
struct PopButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}
