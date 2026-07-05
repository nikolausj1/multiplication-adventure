import Foundation
import SwiftData

/// Debug (-dumpQuestPlan): simulates 10 quest sessions against the REAL engine
/// with a synthetic learner — instant on ×0/×1 tricks and known easy tables
/// (2/5/10), slow on first meetings with new tables — and prints every question
/// to stdout, one session per "day". Uses an in-memory store; real data untouched.
@MainActor
enum QuestPlanDump {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-dumpQuestPlan") else { return }
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: Fact.self, Profile.self, SessionRecord.self, MilestoneRecord.self,
            configurations: config) else { print("DUMP: container failed"); exit(1) }
        let service = LearningService(context: container.mainContext)
        service.bootstrap()

        var simDate = Date.now
        var exposures: [FactID: Int] = [:]   // carried across days (memory of meetings)

        for session in 1...10 {
            // Boss-ready (5 sockets filled)? Fight it first, as the kid would.
            let worldIdx = service.currentWorldIdx()
            if service.starsInCurrentWorld() == 5,
               !service.activeProfile().clearedWorlds.contains(worldIdx) {
                let boss = SessionViewModel(service: service, boss: true, worldIndex: worldIdx)
                boss.now = { simDate }
                boss.sessionStart = simDate
                while boss.stage != .finished {
                    guard let q = boss.current else { break }
                    simDate += 3
                    boss.answer(q.expectedAnswer, simulatedRT: 1.8)
                    boss.pendingCelebration = nil
                    if boss.stage == .feedback { boss.next() }
                }
                let bossName = WorldCatalog.worlds[safe: worldIdx]?.bossName ?? "Boss"
                print("\n⚔️  BOSS FIGHT: \(bossName) — "
                      + (boss.bossPassed ? "DEFEATED, world \(worldIdx + 1) cleared!" : "held off"))
            }
            let vm = SessionViewModel(service: service)
            vm.now = { simDate }
            vm.sessionStart = simDate
            let world = WorldCatalog.worlds[safe: vm.worldStatBefore.index]?.name ?? "?"
            print("\n━━━ SESSION \(session) — \(world) ━━━")
            var n = 0
            while vm.stage != .finished, n < 400 {
                guard let q = vm.current else { break }
                n += 1
                // Learner model: ×0/×1 rules instant; 2/5/10 tables known-fast;
                // anything else slow on the first two meetings, quick after.
                let trivial = q.fact.a <= 1 || q.fact.b <= 1
                let easy = [2, 5, 10].contains(q.fact.a) && [2, 5, 10].contains(q.fact.b)
                let seen = exposures[q.fact, default: 0]
                exposures[q.fact] = seen + 1
                let rt: Double = q.missingFactor ? 4.5
                    : (trivial || easy) ? 1.8
                    : (seen < 2 ? 6.0 : 2.6)
                let tag = q.format == .recognition ? "C " : (q.missingFactor ? "MF" : "K ")
                print(String(format: "%3d [%@] %@", n, tag, q.displayText))
                simDate += rt + 1.2   // answer + feedback beat
                vm.answer(q.expectedAnswer, simulatedRT: rt)
                vm.pendingCelebration = nil
                if vm.stage == .feedback { vm.next() }
                if vm.pendingStarEarned != nil { vm.starEarnedDismissed() }
            }
            print("→ \(vm.totalAnswered) answers, ~\(Int((vm.elapsed / 60).rounded())) min, "
                  + "star \(vm.starEarnedThisSession ? "EARNED" : "not earned"), "
                  + "world \(service.currentWorldIdx() + 1) stars \(service.starsInCurrentWorld())/5")
            simDate += 86_400   // next day
        }
        exit(0)
    }
}
