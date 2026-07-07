import SwiftUI

/// One-time takeover when boss 7 falls and the whole map is cleared:
/// "YOU BEAT THE MAP!" over the seven conquered world badges, then a pointer
/// at what's next (the Master Quest → the certificate). Uses `trophy_gold`
/// art when it exists; a golden SF trophy stands in until then.
struct MapCompleteOverlay: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false      // scrim + trophy fade/scale in
    @State private var landed = false     // title slams, badges + text follow

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.82 : 0).ignoresSafeArea()

            VStack(spacing: 26) {
                trophy
                    .scaleEffect(shown ? 1 : 2.6)
                    .opacity(shown ? 1 : 0)
                    .overlay {
                        if landed {
                            ParticleBurst(kind: .stars,
                                          colors: [Theme.Color.accent, .white,
                                                   Color(red: 1, green: 0.5, blue: 0.15)],
                                          count: 24)
                                .frame(width: 460, height: 460)
                        }
                    }

                Text("YOU BEAT THE MAP!")
                    .font(Theme.Font.display(60)).foregroundStyle(.white)
                    .tracking(2)
                    .shadow(color: .black.opacity(0.6), radius: 5, y: 3)
                    .scaleEffect(landed ? 1 : 1.4)
                    .opacity(landed ? 1 : 0)

                Text("All Seven Worlds conquered — every guardian defeated!")
                    .font(Theme.Font.body(22)).foregroundStyle(.white.opacity(0.9))
                    .opacity(landed ? 1 : 0)

                // The seven conquered worlds take a bow.
                HStack(spacing: 16) {
                    ForEach(WorldCatalog.worlds, id: \.index) { w in
                        let theme = WorldTheme.forWorld(w.index)
                        Group {
                            if Art.exists(theme.nodeImage) {
                                Image(theme.nodeImage).resizable().scaledToFit()
                            } else {
                                Circle().fill(theme.primary)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.Color.accent, lineWidth: 2))
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    }
                }
                .opacity(landed ? 1 : 0)

                Text("The MASTER QUEST begins — master every fact to claim your certificate!")
                    .font(Theme.Font.label(17)).foregroundStyle(Theme.Color.accent)
                    .multilineTextAlignment(.center)
                    .opacity(landed ? 1 : 0)

                Text("Tap to continue")
                    .font(Theme.Font.label(16)).foregroundStyle(.white.opacity(0.55))
                    .opacity(landed ? 1 : 0)
                    .padding(.top, 4)
            }
            .padding(46)
        }
        .contentShape(Rectangle())
        .onTapGesture { if landed || reduceMotion { onDone() } }
        .onAppear { run() }
        .accessibilityLabel("You beat the map! All seven worlds conquered.")
    }

    @ViewBuilder
    private var trophy: some View {
        if Art.exists("trophy_gold") {
            Image("trophy_gold").resizable().scaledToFit()
                .frame(height: 190)
                .shadow(color: Theme.Color.accent.opacity(0.55), radius: 26)
        } else {
            Image(systemName: "trophy.fill")
                .font(.system(size: 130))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35),
                                                         Color(red: 0.95, green: 0.63, blue: 0.1)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.Color.accent.opacity(0.55), radius: 26)
        }
    }

    private func run() {
        Feedback.fire(.bossDefeat)
        guard !reduceMotion else { shown = true; landed = true; return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shown = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62).delay(0.4)) { landed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { Feedback.fire(.starSlam) }
    }
}
