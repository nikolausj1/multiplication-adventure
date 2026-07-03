import SwiftUI

/// Milestone celebration (T2+). Intensity scales with tier; coincident milestones
/// were already merged into one. Auto-dismisses after the tier's duration.
struct CelebrationOverlay: View {
    let celebration: Celebration
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.worldTheme) private var worldTheme
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.45 : 0).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            if tier >= .t3 {
                ParticleBurst(kind: .confetti,
                              colors: [Theme.Color.accent, Theme.Color.correct,
                                       worldTheme.primary, .white, worldTheme.accent],
                              origin: UnitPoint(x: 0.5, y: 0.42),
                              count: tier == .t4 ? 150 : 90)
                    .ignoresSafeArea()
            } else if tier == .t2 {
                ParticleBurst(kind: .stars,
                              colors: [Theme.Color.accent, .white],
                              count: 16)
                    .frame(width: 380, height: 380)
            }
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: tier == .t4 ? 120 : 84))
                    .foregroundStyle(Theme.Color.accent)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.3))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (shown ? 0 : -20)))
                Text(celebration.headline)
                    .font(Theme.Font.display(tier == .t4 ? 40 : 30))
                    .foregroundStyle(.white).multilineTextAlignment(.center)
                ForEach(celebration.lines, id: \.self) { line in
                    Text(line).font(Theme.Font.body()).foregroundStyle(.white.opacity(0.85))
                }
                if tier >= .t3 {
                    Text("Tap to continue").font(Theme.Font.label())
                        .foregroundStyle(.white.opacity(0.6)).padding(.top, 8)
                }
            }
            .padding(40)
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.8))
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? Theme.Motion.quick : Theme.Motion.celebrate) { shown = true }
            // Lower tiers auto-dismiss; major beats wait for a tap.
            if tier < .t3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.duration(tier)) {
                    onDismiss()
                }
            }
        }
    }

    private var tier: CelebrationTier { celebration.tier }
    private var symbol: String {
        switch tier {
        case .t4: return "trophy.fill"
        case .t3: return "rosette"
        default:  return "star.circle.fill"
        }
    }
}
