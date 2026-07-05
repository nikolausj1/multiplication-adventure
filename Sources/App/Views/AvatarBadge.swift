import SwiftUI

/// The 8 avatar slots. Art arrives later as imagesets `avatar1`…`avatar8`;
/// until then each slot renders a themed SF symbol on its own gem circle.
/// Legacy profiles may still store a raw SF symbol name — tier 3 handles them.
enum AvatarCatalog {
    static let keys = (1...8).map { "avatar\($0)" }

    static let fallbacks: [String: (symbol: String, color: Color)] = [
        "avatar1": ("figure.hiking",   Color(red: 0.36, green: 0.68, blue: 0.35)),   // explorer green
        "avatar2": ("pawprint.fill",   Color(red: 0.95, green: 0.55, blue: 0.20)),   // fox orange
        "avatar3": ("flame.fill",      Color(red: 0.85, green: 0.30, blue: 0.25)),   // dragon red
        "avatar4": ("wand.and.stars",  Color(red: 0.58, green: 0.42, blue: 0.88)),   // wizard purple
        "avatar5": ("shield.fill",     Color(red: 0.30, green: 0.50, blue: 0.95)),   // knight blue
        "avatar6": ("airplane",        Color(red: 0.18, green: 0.65, blue: 0.62)),   // pilot teal
        "avatar7": ("bolt.fill",       Color(red: 0.95, green: 0.72, blue: 0.20)),   // storm gold
        "avatar8": ("moon.stars.fill", Color(red: 0.36, green: 0.38, blue: 0.75)),   // owl indigo
    ]
}

/// A circular avatar: real art when the imageset exists, themed symbol fallback
/// otherwise, and a raw-SF-symbol tier for legacy profile values.
struct AvatarBadge: View {
    let key: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if Art.exists(key) {
                Image(key).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                let fb = AvatarCatalog.fallbacks[key]
                let color = fb?.color ?? Theme.Color.primary
                Image(systemName: fb?.symbol ?? key)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(
                        Circle().fill(LinearGradient(colors: [color.shaded(by: 0.2),
                                                              color.shaded(by: -0.2)],
                                                     startPoint: .top, endPoint: .bottom)))
            }
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: max(1.5, size * 0.02)))
    }
}

/// Horizontal snapping picker: the centered avatar is the selection. Reused by
/// onboarding and the kid profile screen.
struct AvatarCarousel: View {
    @Binding var selected: String
    var itemSize: CGFloat = 130

    @State private var position: String?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(AvatarCatalog.keys, id: \.self) { key in
                        AvatarBadge(key: key, size: itemSize)
                            .scrollTransition(axis: .horizontal) { view, phase in
                                view.scaleEffect(phase.isIdentity ? 1.0 : 0.68)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                            }
                            .overlay {
                                if key == selected {
                                    Circle().strokeBorder(Theme.Color.accent, lineWidth: 4)
                                        .shadow(color: Theme.Color.accent.opacity(0.6), radius: 8)
                                }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (geo.size.width - itemSize) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            .onChange(of: position) { _, new in
                if let new, new != selected {
                    selected = new
                    Feedback.fire(.keyTap)
                }
            }
            .onAppear { position = selected }
        }
        .frame(height: itemSize + 24)
        .overlay(alignment: .bottom) {
            HStack(spacing: 7) {
                ForEach(AvatarCatalog.keys, id: \.self) { key in
                    Circle().fill(key == selected ? Theme.Color.accent : .white.opacity(0.3))
                        .frame(width: key == selected ? 9 : 6, height: key == selected ? 9 : 6)
                }
            }
            .offset(y: 18)
        }
    }
}
