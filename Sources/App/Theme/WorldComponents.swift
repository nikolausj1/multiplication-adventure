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
                Image(theme.bgImage).resizable().scaledToFill()
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
        let insets = EdgeInsets(top: s.height * 0.34, leading: s.width * 0.16,
                                bottom: s.height * 0.34, trailing: s.width * 0.16)
        return Image(uiImage: ui).resizable(capInsets: insets, resizingMode: .stretch)
        #else
        return nil
        #endif
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
