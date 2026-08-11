import SwiftUI

/// Golden Guardians phase 4, beat 1: the moment all seven guardians are
/// gilded. A takeover showing all seven in full gold, standing together —
/// not defeated villains, guardians who were testing him and now salute him.
/// Closely patterned on `MapCompleteOverlay` (scrim takeover, tap to
/// continue), reusing `GuardianNodeBadge` in its gilded treatment: no new art.
struct GuardiansAssembleOverlay: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @State private var shown = false      // scrim + guardian row fade/scale in
    @State private var landed = false     // headline slams, lines + text follow

    private var compact: Bool { vSize == .compact }

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.86 : 0).ignoresSafeArea()

            VStack(spacing: compact ? 10 : 20) {
                Text("THE GUARDIANS SALUTE YOU!")
                    .font(Theme.Font.display(compact ? 24 : 42)).foregroundStyle(.white)
                    .tracking(1.5)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                    .scaleEffect(landed ? 1 : 1.4)
                    .opacity(landed ? 1 : 0)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                // All seven, gilded, standing together — the whole beat.
                HStack(spacing: compact ? 7 : 14) {
                    ForEach(WorldCatalog.worlds, id: \.index) { w in
                        GuardianNodeBadge(theme: .forWorld(w.index), gilded: true,
                                          diameter: compact ? 46 : 76)
                    }
                }
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .overlay {
                    if landed {
                        ParticleBurst(kind: .stars,
                                      colors: [Theme.Color.accent, .white,
                                               Color(red: 1, green: 0.5, blue: 0.15)],
                                      count: 24)
                            .frame(width: 520, height: 220)
                    }
                }

                VStack(spacing: compact ? 3 : 6) {
                    Text("They were never your enemies.")
                        .font(Theme.Font.body(compact ? 14 : 19)).foregroundStyle(.white.opacity(0.9))
                    Text("Seven worlds. Seven guardians. All gold.")
                        .font(Theme.Font.label(compact ? 14 : 19)).foregroundStyle(Theme.Color.accent)
                }
                .multilineTextAlignment(.center)
                .opacity(landed ? 1 : 0)

                Text("Tap to continue")
                    .font(Theme.Font.label(compact ? 13 : 16)).foregroundStyle(.white.opacity(0.55))
                    .opacity(landed ? 1 : 0)
                    .padding(.top, 2)
            }
            .padding(compact ? 16 : 40)
        }
        .contentShape(Rectangle())
        .onTapGesture { if landed || reduceMotion { onDone() } }
        .onAppear { run() }
        .accessibilityLabel("The guardians salute you. They were never your enemies. Seven worlds, seven guardians, all gold.")
    }

    private func run() {
        Feedback.fire(.bossDefeat)
        guard !reduceMotion else { shown = true; landed = true; return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shown = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62).delay(0.4)) { landed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { Feedback.fire(.starSlam) }
    }
}
