import SwiftUI

/// The world's guardian during a boss fight: portrait, name plate, and a health
/// bar that drops with every correct answer. The guardian flinches on each hit
/// and slumps, desaturated, once enough hits have landed to win.
struct BossPanel: View {
    let theme: WorldTheme
    let hits: Int
    let hpTotal: Int
    var lastHitCritical: Bool = false

    private var bossName: String { theme.world.bossName }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @State private var shakePhase: CGFloat = 0
    @State private var burst = 0
    @State private var showCrit = false

    private var hpFraction: Double { max(0, 1 - Double(hits) / Double(hpTotal)) }
    private var defeated: Bool { hits >= hpTotal }

    var body: some View {
        VStack(spacing: 14) {
            Image(theme.bossImage)
                .resizable().scaledToFit()
                .frame(maxHeight: vSize == .compact ? 190 : 400)
                .saturation(defeated ? 0.25 : 1)
                .opacity(defeated ? 0.6 : 1)
                .rotationEffect(defeated ? .degrees(7) : .zero)
                .modifier(Shake(travel: 10, shakesPerUnit: 3,
                                animatableData: reduceMotion ? 0 : shakePhase))
                .overlay {
                    if burst > 0 && !defeated {
                        ParticleBurst(kind: .stars, colors: [.white, Theme.Color.accent],
                                      count: showCrit ? 18 : 8, seed: UInt64(burst))
                            .frame(width: showCrit ? 340 : 240, height: showCrit ? 340 : 240)
                            .id(burst)   // fresh burst per hit
                    }
                }
                .overlay(alignment: .top) {
                    if showCrit {
                        Text("CRITICAL!")
                            .font(Theme.Font.display(30)).tracking(2)
                            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.4),
                                                                     Color(red: 1, green: 0.45, blue: 0.1)],
                                                            startPoint: .top, endPoint: .bottom))
                            .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
                            .rotationEffect(.degrees(-6))
                            .transition(.scale(scale: 2.2).combined(with: .opacity))
                            .padding(.top, -10)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)

            VStack(spacing: 12) {
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
                    .font(Theme.Font.label(18)).tracking(2)
                    .foregroundStyle(defeated ? Theme.Color.accent : .white.opacity(0.95))
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
            }
            .padding(.horizontal, 26)
        }
        .animation(Theme.Motion.celebrate, value: defeated)
        .onChange(of: hits) { _, _ in
            burst += 1
            if lastHitCritical {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { showCrit = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(Theme.Motion.quick) { showCrit = false }
                }
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: lastHitCritical ? 0.55 : 0.4)) {
                shakePhase += lastHitCritical ? 2 : 1   // crits rattle twice as hard
            }
        }
        .accessibilityLabel(defeated ? "\(bossName) defeated"
                            : "\(bossName) health \(Int(hpFraction * 100)) percent")
    }
}
