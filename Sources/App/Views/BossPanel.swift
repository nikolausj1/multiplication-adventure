import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The world's guardian during a boss fight: portrait, name plate, and a health
/// bar that drops with every correct answer. The guardian flinches on each hit
/// and slumps, desaturated, once enough hits have landed to win.
struct BossPanel: View {
    let theme: WorldTheme
    let hits: Int
    let hpTotal: Int
    var lastHitCritical: Bool = false
    /// True during a GOLDEN Guardian fight (`SessionViewModel.golden`). Grades
    /// the boss video/still gold and adds a pulsing gold glow behind it —
    /// entirely additive, so a regular (phase-1) fight with `golden == false`
    /// renders exactly as before.
    var golden: Bool = false

    private var bossName: String { theme.world.bossName }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @State private var shakePhase: CGFloat = 0
    @State private var burst = 0
    @State private var showCrit = false
    @State private var glowBloom = false

    private var hpFraction: Double { max(0, 1 - Double(hits) / Double(hpTotal)) }
    private var defeated: Bool { hits >= hpTotal }

    // The still's own aspect ratio, so the video (which has no intrinsic size
    // as a UIViewRepresentable) is constrained to occupy exactly the space
    // the still would have — keeps the panel layout pixel-identical.
    private var bossAspectRatio: CGFloat? {
        #if canImport(UIKit)
        guard let size = UIImage(named: theme.bossImage)?.size, size.width > 0, size.height > 0 else { return nil }
        return size.width / size.height
        #else
        return nil
        #endif
    }

    // Video plays only while the boss is alive, motion is allowed, this
    // world actually has a video, and we could read the still's aspect
    // ratio to constrain it. Every other case falls back to the still.
    private var showVideo: Bool {
        !defeated && !reduceMotion
            && Art.videoURL(theme.bossVideo) != nil
            && Art.videoAspect(theme.bossVideo) != nil
    }

    @ViewBuilder
    private var bossVisual: some View {
        if showVideo, let url = Art.videoURL(theme.bossVideo),
           let ratio = Art.videoAspect(theme.bossVideo) {
            // NOTE: deliberately bare. The defeat treatment below
            // (saturation/opacity/rotation) and the drop shadow are all
            // compositing filters, and applying any of them to this
            // AVPlayerLayer-backed view makes SwiftUI rasterize it onto an
            // OPAQUE backing — the alpha is lost and the boss renders in a
            // white box. They are identity values while the boss is alive
            // (which is the only time the video shows), so the still branch
            // carries them instead. Don't "tidy" them back onto the outer
            // chain.
            LoopingVideoView(url: url, isPaused: defeated, golden: golden)
                .aspectRatio(ratio, contentMode: .fit)
                .transition(.opacity)
        } else {
            Image(theme.bossImage)
                .resizable().scaledToFit()
                .saturation(defeated ? 0.25 : 1)
                .opacity(defeated ? 0.6 : 1)
                .rotationEffect(defeated ? .degrees(7) : .zero)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                .transition(.opacity)
        }
    }

    /// A slow, breathing radial bloom BEHIND the boss visual — pure SwiftUI,
    /// composited underneath in the view hierarchy rather than as a filter ON
    /// the video, so it never touches the AVPlayerLayer that would lose its
    /// alpha (see the note in `bossVisual`). Static (no pulse) under Reduce
    /// Motion instead of animating.
    @ViewBuilder
    private var goldGlow: some View {
        if golden && !defeated {
            GeometryReader { geo in
                RadialGradient(colors: [Theme.Color.accent.opacity(0.85),
                                        Theme.Color.accent.opacity(0.3),
                                        .clear],
                              center: .center, startRadius: 4,
                              endRadius: min(geo.size.width, geo.size.height) * 0.72)
                    .frame(width: geo.size.width * 1.5, height: geo.size.height * 1.5)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .blur(radius: 24)
                    .opacity(reduceMotion ? 0.65 : (glowBloom ? 0.95 : 0.5))
                    .allowsHitTesting(false)
            }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            bossVisual
                .background(goldGlow)
                .frame(maxHeight: vSize == .compact ? 190 : 470)
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
                // (drop shadow lives on the still branch only — see bossVisual)

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
        .onAppear {
            guard golden, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowBloom = true
            }
        }
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
