import Foundation
import SwiftData

/// Debug (-dumpGoldenSim): drives real Golden Guardian fights through
/// SessionViewModel against an in-memory store, patterned on QuestPlanDump.
/// Verifies the full wiring (LearningService.buildGoldenSession →
/// GoldenFightBuilder → SessionViewModel → LearningService.finishSession) end
/// to end: every owned fact is served exactly once in a stage-answerable
/// format, MC questions are untimed with 4 options, a passing fight gilds the
/// world, a soft-failed fight never does (and never touches `clearedWorlds`),
/// and the day gate still keeps `.mastered` short of 77 after one sitting.
@MainActor
enum GoldenSimDump {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-dumpGoldenSim") else { return }
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: Fact.self, Profile.self, SessionRecord.self, MilestoneRecord.self,
            configurations: config) else { print("GOLDENSIM: container failed"); exit(1) }
        let service = LearningService(context: container.mainContext)
        service.bootstrap()
        service.applyDemoGoldenEra()

        var passed = 0
        var total = 0
        func check(_ cond: Bool, _ msg: String) {
            total += 1
            if cond { passed += 1; print("  PASS: \(msg)") }
            else { print("  FAIL: \(msg)") }
        }

        var simDate = Date.now
        let clearedMaskBefore = service.activeProfile().clearedWorldsMask

        /// Snapshot the stage each owned fact will be interpreted at BEFORE a
        /// fight builds (mirrors GoldenFightBuilder.build's own read: absent
        /// or never-introduced facts are .recognition).
        func preFightStages(_ owned: [FactID]) -> [FactID: MasteryStage] {
            var stages: [FactID: MasteryStage] = [:]
            for id in owned {
                if let s = service.fact(id)?.snapshot, s.introduced { stages[id] = s.stage }
                else { stages[id] = .recognition }
            }
            return stages
        }

        /// Static checks against the built (but not-yet-played) queue: every
        /// owned fact served exactly once, in the format its pre-fight stage
        /// maps to, and MC questions are untimed with 4 options.
        func checkQueue(_ vm: SessionViewModel, worldIndex w: Int, owned: [FactID],
                        preStages: [FactID: MasteryStage], label: String) {
            let served = Set(vm.queue.map(\.fact))
            check(served == Set(owned),
                  "world \(w + 1) \(label): served set == owned set (\(served.count) of \(owned.count))")
            check(vm.queue.count == owned.count,
                  "world \(w + 1) \(label): queue length == owned fact count (\(owned.count))")
            let formatMismatches = vm.queue.filter {
                $0.format != GoldenFightBuilder.format(for: preStages[$0.fact] ?? .recognition)
            }.count
            check(formatMismatches == 0,
                  "world \(w + 1) \(label): 0 of \(vm.queue.count) questions mismatch their pre-fight stage format")
            let mcBad = vm.queue.filter {
                $0.format == .recognition && ($0.timed || ($0.options?.count ?? 0) != 4)
            }.count
            check(mcBad == 0,
                  "world \(w + 1) \(label): 0 of \(vm.queue.count) MC questions are timed or missing 4 options")
        }

        /// Drives a built fight to completion, answering `wrongCount` of the
        /// first questions incorrectly (0 = a clean pass run).
        func drive(_ vm: SessionViewModel, wrongCount: Int) {
            vm.now = { simDate }
            var n = 0
            while vm.stage != .finished {
                guard let q = vm.current else {
                    if vm.stage == .feedback { vm.next(); continue }
                    break
                }
                n += 1
                simDate += 2
                let ans = n <= wrongCount ? q.expectedAnswer + 1000 : q.expectedAnswer
                vm.answer(ans, simulatedRT: 1.5)
                vm.pendingCelebration = nil
                if vm.stage == .feedback { vm.next() }
            }
        }

        for w in 0..<WorldCatalog.count {
            let owned = WorldCatalog.facts(inWorld: w)

            // (b) World 0 only: a deliberately-failed fight first — enough
            // wrong answers to land well below the 85% bar.
            if w == 0 {
                let preStages = preFightStages(owned)
                let vmFail = SessionViewModel(service: service, golden: true, worldIndex: w)
                checkQueue(vmFail, worldIndex: w, owned: owned, preStages: preStages, label: "failed fight")
                let wrongCount = max(2, Int((Double(owned.count) * 0.25).rounded(.up)))
                drive(vmFail, wrongCount: wrongCount)
                check(!service.activeProfile().isGilded(w),
                      "world \(w + 1): a fight below 85% (\(vmFail.correctCount)/\(vmFail.totalAnswered)) does NOT gild the world")
                check(service.activeProfile().clearedWorldsMask == clearedMaskBefore,
                      "world \(w + 1): clearedWorldsMask unchanged by a golden fight (still \(clearedMaskBefore))")
                check(!vmFail.bossPassed, "world \(w + 1): failed fight reports bossPassed == false")
            }

            // (a) The passing fight — answer everything correctly.
            let preStages = preFightStages(owned)
            let vm = SessionViewModel(service: service, golden: true, worldIndex: w)
            checkQueue(vm, worldIndex: w, owned: owned, preStages: preStages, label: "passing fight")
            drive(vm, wrongCount: 0)
            check(vm.bossPassed, "world \(w + 1): all-correct fight reports bossPassed == true")
            check(service.activeProfile().isGilded(w), "world \(w + 1): a passing fight gilds the world")
            // The guardian must never die early and cut questions: a golden
            // fight's HP spans the whole gauntlet, so even a flawless run asks
            // every owned fact (the spec's "serves the entire fact set, once").
            check(vm.totalAnswered == owned.count,
                  "world \(w + 1): passing fight asked every question (\(vm.totalAnswered) of \(owned.count))")
        }

        check(service.activeProfile().gildedWorlds.count == WorldCatalog.count,
              "all \(WorldCatalog.count) worlds gilded (gildedWorlds.count == \(service.activeProfile().gildedWorlds.count))")
        check(service.activeProfile().masteredCount < FactUniverse.count,
              "day gate holds: masteredCount \(service.activeProfile().masteredCount) < \(FactUniverse.count) after one day")

        print("\nGOLDENSIM: \(passed)/\(total) \(passed == total ? "PASS" : "FAIL")")
        fflush(stdout)
        exit(passed == total ? 0 : 1)
    }
}
