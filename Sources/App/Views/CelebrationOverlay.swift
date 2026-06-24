import SwiftUI

/// Milestone celebration (T2+). Intensity scales with tier; coincident milestones
/// were already merged into one. Auto-dismisses after the tier's duration.
struct CelebrationOverlay: View {
    let celebration: Celebration
    let onDismiss: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.45 : 0).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: tier == .t4 ? 120 : 84))
                    .foregroundStyle(Theme.Color.accent)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(shown ? 1 : 0.3)
                    .rotationEffect(.degrees(shown ? 0 : -20))
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
            .scaleEffect(shown ? 1 : 0.8)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(Theme.Motion.celebrate) { shown = true }
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
