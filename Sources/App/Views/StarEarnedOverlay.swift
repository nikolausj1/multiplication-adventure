import SwiftUI

/// Full-screen "STAR EARNED" moment: the world's five star sockets fill the screen,
/// already-earned stars sit in place, and the new star slams into its vacant socket
/// with an impact shake and spark burst. Tap to continue; Reduced Motion just fades.
struct StarEarnedOverlay: View {
    let worldName: String
    /// 0-based index of the star that was just earned (existing stars: 0..<index).
    let newStarIndex: Int
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false        // the new star has hit its socket
    @State private var impact = false        // brief shake + flash on landing
    @State private var shown = false         // scrim/text fade-in

    private let starSize: CGFloat = 122

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.8 : 0).ignoresSafeArea()

            VStack(spacing: 40) {
                Text("STAR EARNED!")
                    .font(Theme.Font.display(58)).foregroundStyle(.white)
                    .tracking(2.5)
                    .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                    .scaleEffect(shown ? 1 : 0.7)

                HStack(spacing: 26) {
                    ForEach(0..<WorldStars.starCount, id: \.self) { i in
                        socket(i)
                    }
                }
                .modifier(Shake(travel: 11, shakesPerUnit: 3, animatableData: impact ? 1 : 0))

                VStack(spacing: 10) {
                    Text(worldName)
                        .font(Theme.Font.label(24)).foregroundStyle(.white.opacity(0.85))
                    Text(remainingText)
                        .font(Theme.Font.body(27)).foregroundStyle(Theme.Color.accent)
                        .multilineTextAlignment(.center)
                }
                .opacity(landed ? 1 : 0)

                Text("Tap to continue")
                    .font(Theme.Font.label(17)).foregroundStyle(.white.opacity(0.55))
                    .opacity(landed ? 1 : 0)
            }
            .padding(40)
        }
        .contentShape(Rectangle())
        .onTapGesture { if landed || reduceMotion { onDone() } }
        .onAppear { run() }
    }

    @ViewBuilder
    private func socket(_ i: Int) -> some View {
        ZStack {
            StarGlyph(filled: false, size: starSize)
            if i < newStarIndex {
                StarGlyph(filled: true, size: starSize)          // already earned
            } else if i == newStarIndex {
                StarGlyph(filled: true, size: starSize)          // the new one
                    .scaleEffect(reduceMotion ? 1 : (landed ? 1 : 3.4))
                    .rotationEffect(.degrees(reduceMotion || landed ? 0 : -35))
                    .opacity(reduceMotion ? (landed ? 1 : 0) : (shown ? 1 : 0))
                    .overlay {
                        if impact {
                            ParticleBurst(kind: .stars,
                                          colors: [Theme.Color.accent, .white], count: 16)
                                .frame(width: 380, height: 380)
                        }
                    }
            }
        }
    }

    private var remainingText: String {
        let left = WorldStars.starCount - (newStarIndex + 1)
        if left == 0 { return "All 5 stars — the BOSS CHALLENGE is unlocked on the map!" }
        return left == 1 ? "1 more star to the BOSS CHALLENGE!"
                         : "\(left) more stars to the BOSS CHALLENGE!"
    }

    private func run() {
        withAnimation(Theme.Motion.quick) { shown = true }
        guard !reduceMotion else {
            withAnimation(Theme.Motion.quick) { landed = true }
            return
        }
        // Star hangs huge for a beat, then slams down into its socket.
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(0.35)) {
            landed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.easeOut(duration: 0.45)) { impact = true }
            Feedback.fire(.starSlam)
        }
    }
}
