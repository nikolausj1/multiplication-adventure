import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full-screen world background art with a legibility darkening scrim. Falls back to
/// a palette gradient before the art is added.
struct WorldBackdrop: View {
    let theme: WorldTheme
    var darken: Double = 0.28

    var body: some View {
        ZStack {
            if Art.exists(theme.bgImage) {
                // Contained fill: the overlay keeps the image's oversize out of
                // layout, so a 4:3 screen (12.9" iPad) doesn't inflate the ZStack
                // and push siblings' edges off-screen.
                Color.clear
                    .overlay(Image(theme.bgImage).resizable().scaledToFill())
                    .clipped()
            } else {
                LinearGradient(colors: [theme.primary, theme.deep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            Color.black.opacity(darken)
        }
        .ignoresSafeArea()
    }
}

/// A translucent panel that guarantees content stays readable over busy art.
struct ScrimCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}
extension View {
    func scrimCard() -> some View { modifier(ScrimCard()) }

    /// Dark glass plate: keeps white text readable over any world art without
    /// covering the environment in a big light card. Use per element, not per screen.
    func darkPlate(corner: CGFloat = Theme.Metric.corner) -> some View {
        self
            .background(.ultraThinMaterial.opacity(0.9))
            .environment(\.colorScheme, .dark)   // keep the material glass, not milk
            .background(Color.black.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

/// Chunky 3D game key: lit face on a darker base that physically depresses on touch.
/// Tinted per world; subtle noise texture so flat colour reads as material.
struct ChunkyKeyStyle: ButtonStyle {
    var base: Color
    var deep: Color
    var corner: CGFloat = Theme.Metric.cornerSmall
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return configuration.label
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            .background(
                ZStack {
                    shape.fill(LinearGradient(colors: [base.shaded(by: 0.28), base, base.shaded(by: -0.15)],
                                              startPoint: .top, endPoint: .bottom))
                    Textures.noise
                        .opacity(0.10)
                        .blendMode(.overlay)
                        .clipShape(shape)
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5)
                }
            )
            .offset(y: pressed ? 3 : 0)
            .background(
                shape.fill(deep.shaded(by: -0.3))
                    .offset(y: pressed ? 3.5 : 5)
            )
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

/// Tiny tiled monochrome noise so solid fills feel like a material, not a vector.
enum Textures {
    static let noise: Image = {
        #if canImport(UIKit)
        let side = 64
        var rng = SplitMix64(seed: 0xA11CE)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let ui = renderer.image { ctx in
            for y in 0..<side {
                for x in 0..<side {
                    let v = CGFloat(rng.next() % 256) / 255
                    ctx.cgContext.setFillColor(UIColor(white: v, alpha: 1).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return Image(uiImage: ui).resizable(resizingMode: .tile)
        #else
        return Image(systemName: "square")
        #endif
    }()
}

extension Color {
    /// Lighten (positive) or darken (negative) toward white/black in RGB space.
    func shaded(by amount: Double) -> Color {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let t = CGFloat(min(max(amount, -1), 1))
        func mix(_ c: CGFloat) -> CGFloat { t >= 0 ? c + (1 - c) * t : c * (1 + t) }
        return Color(red: mix(r), green: mix(g), blue: mix(b)).opacity(a)
        #else
        return self
        #endif
    }
}

/// The world's 9-slice button skin (falls back to a palette-filled capsule).
struct WorldButtonBackground: View {
    let theme: WorldTheme
    var body: some View {
        if let img = Self.skin(theme.buttonImage) {
            img
        } else {
            RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous)
                .fill(LinearGradient(colors: [theme.primary, theme.deep],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: Theme.Metric.corner)
                    .strokeBorder(theme.accent.opacity(0.8), lineWidth: 3))
        }
    }

    static func skin(_ name: String) -> Image? {
        #if canImport(UIKit)
        guard let ui = UIImage(named: name) else { return nil }
        let s = ui.size
        // Small caps so the framed button can render at modest heights without overflowing.
        let insets = EdgeInsets(top: s.height * 0.12, leading: s.width * 0.10,
                                bottom: s.height * 0.12, trailing: s.width * 0.10)
        return Image(uiImage: ui).resizable(capInsets: insets, resizingMode: .stretch)
        #else
        return nil
        #endif
    }
}

/// Horizontal shake (locked-node nudges, star-slam impacts); integer phases land
/// at zero offset so the view always settles exactly in place.
struct Shake: GeometryEffect {
    var travel: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2), y: 0))
    }
}

/// One star — gold art when earned, stone socket when vacant (SF fallback pre-art).
struct StarGlyph: View {
    let filled: Bool
    var size: CGFloat = 15

    var body: some View {
        if Art.exists(filled ? "star_gold" : "star_empty") {
            Image(filled ? "star_gold" : "star_empty")
                .resizable().scaledToFit()
                .frame(width: size * 1.25, height: size * 1.25)
                .shadow(color: .black.opacity(filled ? 0.45 : 0.3), radius: size * 0.08, y: size * 0.05)
        } else {
            Image(systemName: filled ? "star.fill" : "star")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(filled
                    ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35),
                                                            Color(red: 0.95, green: 0.63, blue: 0.1)],
                                                   startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.45)))
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
        }
    }
}

/// World progress as stars (game-style): one star per completed daily quest,
/// five sockets per world. Filled stars are gold; empty sockets visibly wait.
struct WorldStars: View {
    let filled: Int
    var size: CGFloat = 15
    var spacing: CGFloat = 3

    static let starCount = 5

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<Self.starCount, id: \.self) { i in
                StarGlyph(filled: i < filled, size: size)
            }
        }
        .accessibilityLabel("\(filled) of \(Self.starCount) stars")
    }
}

/// The chunky orange close key used by all modal cards (upper-left corner).
struct ModalCloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
        }
        .buttonStyle(ChunkyKeyStyle(base: Theme.Color.accent,
                                    deep: Theme.Color.accent.shaded(by: -0.4),
                                    corner: 20))
        .accessibilityLabel("Close")
    }
}

/// A world map node badge (art) or a palette fallback circle.
struct WorldNodeBadge: View {
    let theme: WorldTheme
    var body: some View {
        if Art.exists(theme.nodeImage) {
            Image(theme.nodeImage).resizable().scaledToFit()
        } else {
            Circle()
                .fill(LinearGradient(colors: [theme.primary, theme.deep],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Image(systemName: "star.fill").foregroundStyle(theme.accent).font(.system(size: 28)))
        }
    }
}
