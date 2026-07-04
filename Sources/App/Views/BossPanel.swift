import SwiftUI

/// The world's guardian during a boss fight: portrait, name plate, and a health
/// bar that drops with every correct answer. The guardian flinches on each hit
/// and slumps, desaturated, once enough hits have landed to win.
struct BossPanel: View {
    let theme: WorldTheme
    let hits: Int
    let hpTotal: Int

    private var bossName: String { theme.world.bossName }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakePhase: CGFloat = 0
    @State private var burst = 0

    private var hpFraction: Double { max(0, 1 - Double(hits) / Double(hpTotal)) }
    private var defeated: Bool { hits >= hpTotal }

    var body: some View {
        VStack(spacing: 14) {
            Image(theme.bossImage)
                .resizable().scaledToFit()
                .frame(maxHeight: 400)
                .saturation(defeated ? 0.25 : 1)
                .opacity(defeated ? 0.6 : 1)
                .rotationEffect(defeated ? .degrees(7) : .zero)
                .modifier(Shake(travel: 10, shakesPerUnit: 3,
                                animatableData: reduceMotion ? 0 : shakePhase))
                .overlay {
                    if burst > 0 && !defeated {
                        ParticleBurst(kind: .stars, colors: [.white, Theme.Color.accent],
                                      count: 8, seed: UInt64(burst))
                            .frame(width: 240, height: 240)
                            .id(burst)   // fresh burst per hit
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)

            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.45))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.3, blue: 0.2),
                                                          Color(red: 0.7, green: 0.08, blue: 0.1)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: max(0, geo.size.width * hpFraction))
                    }
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                }
                .frame(height: 16)
                .animation(Theme.Motion.snappy, value: hpFraction)

                Text(defeated ? "\(bossName.uppercased()) DEFEATED!" : bossName.uppercased())
                    .font(Theme.Font.label(13)).tracking(1.5)
                    .foregroundStyle(defeated ? Theme.Color.accent : .white.opacity(0.9))
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            }
            .padding(.horizontal, 26)
        }
        .animation(Theme.Motion.celebrate, value: defeated)
        .onChange(of: hits) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.4)) { shakePhase += 1 }
            burst += 1
        }
        .accessibilityLabel(defeated ? "\(bossName) defeated"
                            : "\(bossName) health \(Int(hpFraction * 100)) percent")
    }
}
