import SwiftUI
import SwiftData

/// Session wrap (§6, movement 4): a clear, encouraging summary on a scrim panel over
/// the world backdrop. He always leaves knowing he made progress.
struct WrapView: View {
    @Environment(\.worldTheme) private var theme
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]
    let vm: SessionViewModel
    let onDone: () -> Void

    private var snapshots: [FactSnapshot] { (activeProfiles.first?.facts ?? []).map(\.snapshot) }

    /// This session took the world it started in from not-cleared to cleared.
    private var clearedThisSession: Bool {
        let before = vm.worldStatBefore
        guard before.total > 0, before.fluent < before.total else { return false }
        return WorldProgress.stats(snapshots: snapshots)[safe: before.index]?.cleared ?? false
    }

    private var clearedName: String {
        WorldCatalog.worlds[safe: vm.worldStatBefore.index]?.name ?? "World"
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: clearedThisSession ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(clearedThisSession ? Theme.Color.accent : Theme.Color.correct)
                .symbolRenderingMode(.hierarchical)
                .background {
                    ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 14)
                        .frame(width: 260, height: 260)
                }
            Text(clearedThisSession ? "\(clearedName) cleared!" : "Great work!")
                .font(Theme.Font.display(34)).foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                stat("\(vm.totalAnswered)", "questions")
                stat("\(Int(vm.accuracy * 100))%", "accuracy")
                stat("+\(vm.xpEarned)", "XP", tint: Theme.Color.accent)
            }

            worldProgressCard

            if let c = vm.endCelebration, c.tier >= .t1 {
                Label(c.headline, systemImage: "flame.fill")
                    .font(Theme.Font.label(17)).foregroundStyle(Theme.Color.accent)
            }
            Text(encouragement).font(Theme.Font.body()).foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button(action: onDone) {
                Text("Back to Map").font(Theme.Font.display(20))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
            }
            .buttonStyle(ChunkyKeyStyle(base: theme.primary, deep: theme.deep,
                                        corner: Theme.Metric.corner))
        }
        .padding(Theme.Metric.pad + 8)
        .frame(maxWidth: 500)
        .darkPlate()
        .padding(Theme.Metric.pad)
        .background {
            if clearedThisSession {
                ParticleBurst(kind: .confetti,
                              colors: [Theme.Color.accent, Theme.Color.correct,
                                       theme.primary, .white, theme.accent],
                              origin: UnitPoint(x: 0.5, y: 0.3), count: 120)
                    .frame(width: 900, height: 800)
            }
        }
    }

    private func stat(_ value: String, _ label: String, tint: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.Font.number(30)).foregroundStyle(tint)
            Text(label).font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.65))
        }
    }

    /// The "why am I replaying this world" answer: a visible bar, today's gains, and
    /// one line that explains the loop (facts drip in daily; fluent-all clears it).
    @ViewBuilder
    private var worldProgressCard: some View {
        let stats = WorldProgress.stats(snapshots: snapshots)
        let idx = WorldProgress.currentIndex(snapshots: snapshots)
        let s = stats[safe: idx]
        let fluent = s?.fluentPlus ?? 0
        let inTraining = max(0, (s?.introduced ?? 0) - fluent)
        let total = max(s?.total ?? 1, 1)
        let name = WorldCatalog.worlds[safe: idx]?.name ?? "this world"
        let gained = max(0, fluent - (vm.worldStatBefore.index == idx ? vm.worldStatBefore.fluent : 0))
        let allCleared = WorldProgress.clearedCount(snapshots: snapshots) == WorldCatalog.count

        VStack(spacing: 8) {
            if allCleared {
                Text("Every world cleared — you're a Multiplication Master!")
                    .font(Theme.Font.body()).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            } else {
                HStack {
                    Text(name).font(Theme.Font.label(15)).foregroundStyle(.white)
                    Spacer()
                    Text("\(fluent)/\(total) facts fluent")
                        .font(Theme.Font.label(14)).foregroundStyle(.white.opacity(0.8))
                }
                // Two segments: green = fluent, soft gold = introduced & in training,
                // so day-one effort shows even before anything turns fluent.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(Theme.Color.accent.opacity(0.45))
                            .frame(width: geo.size.width * CGFloat(fluent + inTraining) / CGFloat(total))
                        Capsule().fill(Theme.Color.correct)
                            .frame(width: geo.size.width * CGFloat(fluent) / CGFloat(total))
                    }
                }
                .frame(height: 8)
                if gained > 0 {
                    Text("+\(gained) new fluent fact\(gained == 1 ? "" : "s") today!")
                        .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.correct)
                } else if inTraining > 0 {
                    Text("\(inTraining) fact\(inTraining == 1 ? "" : "s") in training — every correct answer moves them toward fluent.")
                        .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.accent)
                        .multilineTextAlignment(.center)
                }
                Text(fluent == total
                     ? "World cleared — the next world is open on the map!"
                     : "New facts join a few at a time. When all \(total) are fluent, \(name) is cleared and the next world unlocks.")
                    .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var encouragement: String {
        if vm.accuracy >= 0.9 { return "You're getting faster every day. 🚀" }
        if vm.totalAnswered >= 15 { return "Showing up is what makes it stick. See you tomorrow!" }
        return "Every bit of practice counts. Nice job today!"
    }
}
