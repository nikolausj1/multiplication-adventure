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

    /// Boss victory this session (worlds clear only by beating their boss).
    private var clearedThisSession: Bool { vm.bossWorldIndex != nil && vm.bossPassed }
    private var bossFailed: Bool { vm.bossWorldIndex != nil && !vm.bossPassed }

    private var clearedName: String {
        WorldCatalog.worlds[safe: vm.bossWorldIndex ?? vm.worldStatBefore.index]?.name ?? "World"
    }

    private var headline: String {
        if clearedThisSession { return "\(clearedName) cleared!" }
        if bossFailed { return "So close!" }
        if vm.isQuest && vm.starEarnedThisSession { return "Quest complete!" }
        return "Great work!"
    }

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: clearedThisSession ? "trophy.fill"
                              : (bossFailed ? "flag.checkered" : "checkmark.seal.fill"))
                .font(.system(size: 72))
                .foregroundStyle(clearedThisSession ? Theme.Color.accent
                                 : (bossFailed ? .white : Theme.Color.correct))
                .symbolRenderingMode(.hierarchical)
                .background {
                    if !bossFailed {
                        ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 14)
                            .frame(width: 260, height: 260)
                    }
                }
            Text(headline)
                .font(Theme.Font.display(34)).foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                stat("\(vm.totalAnswered)", "questions")
                stat("\(Int(vm.accuracy * 100))%", "accuracy")
                stat("+\(vm.xpEarned)", "XP", tint: Theme.Color.accent)
            }

            worldProgressCard

            if vm.bossWorldIndex == nil, let c = vm.endCelebration, c.tier >= .t1 {
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
        let cleared = activeProfiles.first?.clearedWorlds ?? []
        let stats = WorldProgress.stats(snapshots: snapshots)
        let idx = WorldProgress.currentIndex(snapshots: snapshots, cleared: cleared)
        let s = stats[safe: idx]
        let fluent = s?.fluentPlus ?? 0
        let inTraining = max(0, (s?.introduced ?? 0) - fluent)
        let total = max(s?.total ?? 1, 1)
        let name = WorldCatalog.worlds[safe: idx]?.name ?? "this world"
        let gained = max(0, fluent - (vm.worldStatBefore.index == idx ? vm.worldStatBefore.fluent : 0))
        let allCleared = cleared.count == WorldCatalog.count

        VStack(spacing: 8) {
            if let bossWorld = vm.bossWorldIndex {
                let boss = WorldCatalog.worlds[safe: bossWorld]?.bossName ?? "Guardian"
                if vm.bossPassed {
                    Text("You defeated the \(boss) — the next world is revealed on the map!")
                        .font(Theme.Font.body()).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                } else {
                    Text("The \(boss) held you off — \(vm.correctCount) of \(vm.totalAnswered), and you need \(Int(LearningService.bossPassAccuracy * 100))%. Train up and challenge it again — retries are free!")
                        .font(Theme.Font.body()).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            } else if allCleared {
                let mastered = snapshots.filter { $0.stage == .mastered }.count
                if mastered >= FactUniverse.count {
                    Text("Every fact mastered — you're a Multiplication Master!")
                        .font(Theme.Font.body()).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                } else {
                    let gainedMastery = max(0, mastered - vm.masteredBefore)
                    HStack {
                        Label("MASTER QUEST", systemImage: "trophy.fill")
                            .font(Theme.Font.label(14)).tracking(1.5)
                            .foregroundStyle(Theme.Color.accent)
                        Spacer()
                        Text("\(mastered)/\(FactUniverse.count) mastered")
                            .font(Theme.Font.label(14)).foregroundStyle(.white.opacity(0.8))
                    }
                    if gainedMastery > 0 {
                        Text("+\(gainedMastery) mastered today!")
                            .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.correct)
                    }
                    Text("Master every fact — fast answers on different days — to claim the trophy certificate!")
                        .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
            } else {
                HStack {
                    Text(name).font(Theme.Font.label(15)).foregroundStyle(.white)
                    Spacer()
                    Text("\(fluent)/\(total) facts fluent")
                        .font(Theme.Font.label(14)).foregroundStyle(.white.opacity(0.8))
                }
                WorldStars(fluent: fluent, total: total, size: 26, spacing: 8)
                    .padding(.vertical, 2)
                if vm.isQuest {
                    if vm.starEarnedThisSession {
                        Label("Quest complete — you're done for today!", systemImage: "flame.fill")
                            .font(Theme.Font.label(15)).foregroundStyle(Theme.Color.accent)
                    } else {
                        Text("Today's star is \(Int(vm.questCharge * 100))% charged — finish it tomorrow!")
                            .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.accent)
                            .multilineTextAlignment(.center)
                    }
                }
                if gained > 0 {
                    Text("+\(gained) new fluent fact\(gained == 1 ? "" : "s") today!")
                        .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.correct)
                } else if inTraining > 0 {
                    Text("\(inTraining) fact\(inTraining == 1 ? "" : "s") in training — every correct answer moves them toward fluent.")
                        .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.accent)
                        .multilineTextAlignment(.center)
                }
                Text(fluent == total
                     ? "All 5 stars earned — the BOSS CHALLENGE is waiting on the map. Beat it to clear \(name)!"
                     : "One quest ≈ one star. Earn all 5 to unlock the \(name) boss challenge.")
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
