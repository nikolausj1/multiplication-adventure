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
/// N sockets per world (the profile's goal — parent-adjustable). Filled stars
/// are gold; empty sockets visibly wait.
struct WorldStars: View {
    let filled: Int
    var total: Int = WorldCatalog.starsPerWorld
    var size: CGFloat = 15
    var spacing: CGFloat = 3

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                StarGlyph(filled: i < filled, size: size)
            }
        }
        .accessibilityLabel("\(filled) of \(total) stars")
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

/// Visual redesign v2: which conquered-node treatment to render, selectable
/// on-device for comparison via `-conqueredStyle <1|2|3>` (idiom mirrors
/// `-gildWorlds` — see `LevelUpMathApp`'s `#if DEBUG` launch-arg parsing,
/// the only place that ever writes `current`). Defaults to `.crown` when the
/// arg is absent, which is also what every Release build renders — nothing
/// outside a `#if DEBUG` block ever sets `current` to anything else.
enum ConqueredStyle: Int {
    case crown = 1, sash = 2, laurel = 3

    static var current: ConqueredStyle = .crown
}

/// Golden Guardians map node (visual redesign, superseding the "dark
/// challenger turns gold" model): the guardian itself — the still
/// `bossImage`, never the boss video, see BossPanel's note on why
/// compositing filters break the video's alpha — is GOLD from the moment
/// the map transforms, in EVERY state. The conquest signal moved to the
/// NODE CIRCLE BACKGROUND instead:
///  - not yet gilded (challenge): a desaturated/grayscale version of the
///    world's own palette gradient behind the gold guardian, dim gold rim —
///    "the guardian has drained this world's color." A slow menacing pulse
///    (gentle scale + glow breathing, ~2.2s loop) rides this state so an
///    unbeaten guardian reads as still-a-threat; it stops dead the moment
///    `gilded` flips true.
///  - gilded (conquered): the world-palette gradient returns at full
///    saturation, the rim/glow brighten, the pulse stops, and one of three
///    `ConqueredStyle` treatments badges the win — see `current`.
/// The circle-background saturation change (and the rim/glow brightening)
/// animate implicitly when `gilded` flips true with the caller inside
/// `withAnimation` (a fight just won, the map returns) and render correctly
/// at rest with no animation when `gilded` is already the view's initial
/// value (a later launch). Self-contained (frame/clip/border/shadow) so
/// callers just drop it in, mirroring how `UnlockedBadge` wraps
/// `WorldNodeBadge` on the map.
struct GuardianNodeBadge: View {
    let theme: WorldTheme
    let gilded: Bool
    var diameter: CGFloat = 104

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var gold: Color { Color(red: 1.0, green: 0.82, blue: 0.35) }
    private var style: ConqueredStyle { ConqueredStyle.current }

    private var rimColors: [Color] {
        guard gilded else { return [gold.opacity(0.75), Color(red: 0.7, green: 0.48, blue: 0.12).opacity(0.75)] }
        // Laurel's "brighter rim" call-out gets a lighter, higher-contrast pair.
        if style == .laurel { return [Color(red: 1, green: 0.99, blue: 0.93), Color(red: 0.96, green: 0.8, blue: 0.35)] }
        return [Color(red: 1, green: 0.97, blue: 0.82), Color(red: 0.87, green: 0.64, blue: 0.18)]
    }
    private var rimWidth: CGFloat {
        guard gilded else { return diameter > 95 ? 3.5 : 2.5 }
        return (style == .laurel ? diameter * 0.055 : diameter * 0.043)
    }
    private var glowRadius: CGFloat {
        guard gilded else { return pulse && !reduceMotion ? 6 : 3 }
        return style == .crown ? 18 : 14   // crown's "stronger outer glow"
    }
    private var glowOpacity: Double {
        guard gilded else { return pulse && !reduceMotion ? 0.28 : 0.12 }
        return style == .crown ? 0.85 : 0.7
    }

    var body: some View {
        ZStack {
            // The conquest signal: the world's own palette, grayscale while
            // challenged, vivid once conquered.
            Circle().fill(LinearGradient(colors: [theme.primary, theme.deep],
                                         startPoint: .top, endPoint: .bottom))
                .saturation(gilded ? 1 : 0)
            // The guardian is gold from the transform onward, in both states.
            if Art.exists(theme.bossImage) {
                Image(theme.bossImage)
                    .resizable().scaledToFill()
                    .saturation(0.25)
                    .brightness(0.18)
                    .colorMultiply(gold)
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: diameter * 0.32))
                    .foregroundStyle(gold)
            }
            // Style 2 "Sash": a diagonal ribbon reading CONQUERED, clipped to
            // the circle along with everything else in this ZStack (unlike
            // the seal/crown below, which deliberately ride outside the
            // clip), so it never spills past the rim.
            if gilded, style == .sash {
                sashRibbon
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(
            LinearGradient(colors: rimColors, startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: rimWidth))
        // Style 1 "Crown": perched on the top rim, replacing the star seal.
        .overlay(alignment: .top) {
            if gilded, style == .crown { crownBadge }
        }
        // Style 3 "Laurel": a wreath hugging the lower rim from outside.
        .overlay(alignment: .bottom) {
            if gilded, style == .laurel { laurelWreath }
        }
        // Conquered seal: kept only for Sash — Crown replaces it outright,
        // and Laurel's wreath already owns the lower rim, so stacking a
        // second badge there would collide with it. A compact secondary cue
        // riding the badge's bottom edge, outside the circle clip (mirroring
        // how the old map's cleared checkmark badges the corner) so it's
        // legible even at a glance that misses the color return.
        .overlay(alignment: .bottom) {
            if gilded, style == .sash {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: diameter * 0.24))
                    .foregroundStyle(gold)
                    .background(Circle().fill(.white).frame(width: diameter * 0.21, height: diameter * 0.21))
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .offset(y: diameter * 0.12)
            }
        }
        .shadow(color: gold.opacity(glowOpacity), radius: glowRadius, y: gilded ? 0 : 2)
        .scaleEffect(!gilded && pulse && !reduceMotion ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.7), value: gilded)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: gilded) { _, newValue in
            if newValue { pulse = false } else { startPulseIfNeeded() }
        }
    }

    /// Slow menacing pulse for an unbeaten guardian — stops dead (static,
    /// calm) once conquered. `repeatForever` on a plain Bool flip is the
    /// same idiom `PulsingRing` already uses for the current-world ring.
    private func startPulseIfNeeded() {
        guard !gilded, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private var crownBadge: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: diameter * 0.22, weight: .bold))
            .foregroundStyle(.white)
            .padding(diameter * 0.09)
            .background(Circle().fill(LinearGradient(
                colors: [Color(red: 1, green: 0.95, blue: 0.75), gold],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .offset(y: -diameter * 0.12)
    }

    private var sashRibbon: some View {
        // The gold band deliberately spans wider than the circle (it's meant
        // to run edge-to-edge and get clipped at the rim by the outer
        // `.clipShape(Circle())`), but the TEXT can't share that width or it
        // clips mid-word ("CONQUERED" → "ONQUERED" at the 82pt iPhone
        // badge). So the label sits in its own narrower frame, shrinking to
        // fit via `minimumScaleFactor` — comfortably inside the circle even
        // after the -20° rotation.
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.75), gold, Color(red: 0.85, green: 0.62, blue: 0.15)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: diameter * 1.6, height: diameter * 0.26)
            Text("CONQUERED")
                .font(.system(size: diameter * 0.078, weight: .heavy, design: .rounded))
                .tracking(0)
                .foregroundStyle(Color.black.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: diameter * 0.82)
        }
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        .rotationEffect(.degrees(-20))
    }

    private var laurelWreath: some View {
        HStack(spacing: -diameter * 0.05) {
            Image(systemName: "laurel.leading")
            Image(systemName: "laurel.trailing")
        }
        .font(.system(size: diameter * 0.4, weight: .bold))
        .foregroundStyle(LinearGradient(
            colors: [Color(red: 1, green: 0.95, blue: 0.75), gold],
            startPoint: .top, endPoint: .bottom))
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .offset(y: diameter * 0.22)
    }
}
