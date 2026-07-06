import Foundation

// A lightweight assertion harness so we can validate the pure engine with `swiftc`
// outside Xcode. Exits non-zero on first failure.
var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ✓ \(msg)") }
    else { print("  ✗ FAIL: \(msg)"); failures += 1 }
}

let now = Date(timeIntervalSince1970: 1_700_000_000)
let day: TimeInterval = 86_400

print("Fact universe")
check(FactUniverse.count == 77, "77 unique facts (0s through 11s, no 11×11)")
check(!FactUniverse.allFacts.contains(FactID(11, 11)), "11×11 is out of scope")
check(!FactUniverse.allFacts.contains(FactID(3, 12)), "no ×12 facts")
check(FactID(8, 7) == FactID(7, 8), "facts are commutative/canonical")
check(FactUniverse.allFacts.allSatisfy { $0.a <= $0.b }, "all stored canonically")

print("Curriculum")
check(Curriculum.slot(of: FactID(0, 0)) == 0, "0×0 introduced first")
check(Curriculum.slot(of: FactID(6, 7)) == Curriculum.introRank(ofFactor: 7), "6×7 unlocks with the 7s")
check(Curriculum.factsBySlot().reduce(0) { $0 + $1.count } == 77, "every fact lands in a slot")

print("Distractors")
let prompt = OrientedPrompt(fact: FactID(7, 8), swapped: false)
let opts = DistractorGenerator.options(for: prompt, seed: 42)
check(opts.count == 4, "four options")
check(opts.contains(56), "includes the correct answer")
check(Set(opts).count == 4, "options are distinct")
check(opts.allSatisfy { $0 >= 0 }, "no negative options")
check(DistractorGenerator.options(for: prompt, seed: 42) == opts, "deterministic for a seed")

print("Leitner")
check(LeitnerScheduler.promote(box: 0, from: now).box == 1, "correct promotes a box")
check(LeitnerScheduler.demote(box: 4, from: now).box == 2, "wrong drops two boxes")
check(LeitnerScheduler.demote(box: 4, from: now).due == now, "wrong re-queues immediately")

print("Promotion: recognition → recall (2 consecutive slow, or 1 fast test-out)")
var f = FactSnapshot(id: FactID(7, 8), introduced: true, stage: .recognition)
f = PromotionEngine.apply(to: f, correct: true, responseTime: 5, fluencyThreshold: 3, now: now).snapshot
check(f.stage == .recognition, "one slow correct stays in recognition")
let o = PromotionEngine.apply(to: f, correct: true, responseTime: 5, fluencyThreshold: 3, now: now)
check(o.snapshot.stage == .recall, "two consecutive correct promotes to recall")
check(o.promotedStage, "promotion flagged")
let ft = FactSnapshot(id: FactID(7, 9), introduced: true, stage: .recognition)
check(PromotionEngine.apply(to: ft, correct: true, responseTime: 1.5, fluencyThreshold: 3,
                            now: now).snapshot.stage == .recall,
      "one FAST correct tests out of recognition")
var rc = FactSnapshot(id: FactID(8, 9), introduced: true, stage: .recall)
rc = PromotionEngine.apply(to: rc, correct: true, responseTime: 1.5, fluencyThreshold: 3, now: now).snapshot
check(rc.stage == .recall, "one fast typed is not yet recall-complete")
check(PromotionEngine.apply(to: rc, correct: true, responseTime: 1.5, fluencyThreshold: 3,
                            now: now).snapshot.stage == .fluency,
      "two fast typed test out of recall")

print("Promotion: a wrong MC resets the streak")
var g = FactSnapshot(id: FactID(3, 4), introduced: true, stage: .recognition, recognitionStreak: 1)
g = PromotionEngine.apply(to: g, correct: false, responseTime: 0, fluencyThreshold: 3, now: now).snapshot
check(g.recognitionStreak == 0, "wrong answer resets recognition streak")

print("Rule facts (×0/×1) fast-track to fluency, then master on a second correct")
var ruleF = FactSnapshot(id: FactID(0, 7), introduced: true, stage: .recognition)
ruleF = PromotionEngine.apply(to: ruleF, correct: true, responseTime: 5, fluencyThreshold: 3,
                              now: now).snapshot
check(ruleF.stage == .fluency, "a ×0/×1 rule fact tests out to fluency on one correct")
let ruleM = PromotionEngine.apply(to: ruleF, correct: true, responseTime: 5, fluencyThreshold: 3, now: now)
check(ruleM.snapshot.stage == .mastered, "a second correct masters it (no cross-day needed)")
check(ruleM.becameMastered, "rule-fact mastery is flagged")

print("Promotion: fluency → mastered requires 3 fast across 2 days")
var h = FactSnapshot(id: FactID(6, 7), introduced: true, stage: .fluency)
h = PromotionEngine.apply(to: h, correct: true, responseTime: 1.5, fluencyThreshold: 3, now: now).snapshot
h = PromotionEngine.apply(to: h, correct: true, responseTime: 1.5, fluencyThreshold: 3, now: now).snapshot
h = PromotionEngine.apply(to: h, correct: true, responseTime: 1.5, fluencyThreshold: 3, now: now).snapshot
check(h.stage == .fluency, "3 fast same-day does NOT master (cross-day rule)")
let m = PromotionEngine.apply(to: h, correct: true, responseTime: 1.5, fluencyThreshold: 3, now: now + day)
check(m.snapshot.stage == .mastered, "a fast-correct on a second day masters it")
check(m.becameMastered, "mastery flagged")

print("Promotion: slow answers never master")
var sFact = FactSnapshot(id: FactID(8, 9), introduced: true, stage: .fluency)
for d in 0..<6 {
    sFact = PromotionEngine.apply(to: sFact, correct: true, responseTime: 4.0,
                                  fluencyThreshold: 3, now: now + Double(d) * day).snapshot
}
check(sFact.stage == .fluency, "correct-but-slow never reaches mastery")

print("Lapse: a mastered fact returns to review, never to zero")
var mFact = FactSnapshot(id: FactID(7, 8), introduced: true, stage: .mastered, masteredDate: now)
let lap = PromotionEngine.apply(to: mFact, correct: false, responseTime: 0, fluencyThreshold: 3, now: now)
check(lap.snapshot.stage == .fluency, "lapsed fact drops to fluency, not zero")
check(lap.snapshot.lapseCount == 1, "lapse counted")
check(lap.lapsed, "lapse flagged")

print("XP shifts from effort to mastery")
let earlyXP = XPEngine.xp(correct: false, responseTime: 0, stage: .recognition, fluencyThreshold: 3, masteryFraction: 0)
let lateMiss = XPEngine.xp(correct: false, responseTime: 0, stage: .recognition, fluencyThreshold: 3, masteryFraction: 1)
check(earlyXP > lateMiss, "a miss pays more early (effort) than late")
let lateFast = XPEngine.xp(correct: true, responseTime: 1, stage: .fluency, fluencyThreshold: 3, masteryFraction: 1)
let earlyFast = XPEngine.xp(correct: true, responseTime: 1, stage: .fluency, fluencyThreshold: 3, masteryFraction: 0)
check(lateFast > earlyFast, "a fast correct pays more late (mastery) than early")

print("Ranks")
check(RankLadder.rank(forMasteredCount: 0).name == "Novice", "starts Novice")
check(RankLadder.rank(forMasteredCount: FactUniverse.count).name == "Master", "Master at full count")
check(RankLadder.next(afterMasteredCount: 0)?.rank.name == "Apprentice", "next rank is Apprentice")

print("Session planner: cold start")
let fresh = FactUniverse.allFacts.map { FactSnapshot(id: $0) }
let plan0 = SessionPlanner.plan(snapshots: fresh, now: now, seed: 1)
check(!plan0.isEmpty, "cold start produces a session")
check(plan0.allSatisfy { $0.movement != .warmup } || plan0.first?.movement == .warmup,
      "no mastered facts → warm-up gracefully empty or leads")
// New facts are capped at 4 distinct per session; each is served twice (intro +
// end-of-session second rep) so recognition completes on day one.
let newFactIDs = Set(plan0.filter { $0.format == .recognition }.map { $0.fact })
let newCount = plan0.filter { $0.format == .recognition }.count
check(newFactIDs.count > 0 && newFactIDs.count <= 4,
      "introduces a capped trickle of distinct new facts (\(newFactIDs.count))")
check(newCount == newFactIDs.count * 2, "each new fact is served twice (\(newCount))")
let lastQs = plan0.suffix(newFactIDs.count).map { $0.fact }
check(Set(lastQs) == newFactIDs, "second reps come at the session's end")
check(plan0.first?.fact == FactID(0, 0) || plan0.contains { $0.fact == FactID(0, 0) },
      "earliest curriculum fact appears first")

print("Session planner: interleaving")
let q = (2...11).flatMap { b in [FactSnapshot(id: FactID(b, b == 11 ? 10 : b), introduced: true, stage: .recall)] }
let interleaved = SessionPlanner.plan(snapshots: q, now: now, seed: 7)
var adjacentSameTable = 0
for i in 1..<interleaved.count where interleaved[i].fact.b == interleaved[i-1].fact.b { adjacentSameTable += 1 }
check(adjacentSameTable == 0, "no two adjacent questions share a table when avoidable")

print("Milestones: coincident events merge to highest tier")
let before = ProgressAggregate(masteredCount: 21, completedFactors: [], clearedWorlds: 0, streakDays: 2)
let after = ProgressAggregate(masteredCount: 23, completedFactors: [7], clearedWorlds: 1, streakDays: 3)
let evs = MilestoneEngine.events(before: before, after: after)
let celebration = MilestoneEngine.merge(evs)
check(celebration?.tier == .t3, "a T3 milestone (world cleared / 25%) wins the merge")
check((celebration?.lines.count ?? 0) >= 2, "lower milestones fold into the lines")
check(evs.contains { if case .worldCleared = $0.kind { return true }; return false }, "world-cleared event emitted")

print("Milestones: completion supersedes all")
let preDone = ProgressAggregate(masteredCount: FactUniverse.count - 1, completedFactors: [], clearedWorlds: 6, streakDays: 6)
let done = ProgressAggregate(masteredCount: FactUniverse.count, completedFactors: [], clearedWorlds: 7, streakDays: 7)
let doneEvents = MilestoneEngine.events(before: preDone, after: done)
check(doneEvents.count == 1 && doneEvents[0].tier == .t4, "100% is a single T4 finale")

print("Worlds")
check(WorldCatalog.count == 7, "7 worlds")
check(WorldCatalog.worldIndex(ofFact: FactID(0,0)) == 0, "0×0 is in the first world")
check(WorldCatalog.worldIndex(ofFact: FactID(8,8)) == 6, "8×8 is in the last world (Sky Citadel = the 8s)")
check((0..<7).reduce(0) { $0 + WorldCatalog.facts(inWorld: $1).count } == 77, "every fact maps to a world")
let freshW = FactUniverse.allFacts.map { FactSnapshot(id: $0) }
check(WorldProgress.currentIndex(snapshots: freshW) == 0, "fresh start is on world 0")
check(WorldProgress.clearedCount(snapshots: freshW) == 0, "nothing cleared at start")
// All world-0 facts at fluency → world 0 clears, current advances.
var w0 = freshW.map { s -> FactSnapshot in
    var s = s
    if WorldCatalog.worldIndex(ofFact: s.id) == 0 { s.introduced = true; s.stage = .fluency }
    return s
}
check(WorldProgress.stats(snapshots: w0)[0].cleared, "world 0 clears when all its facts are fluent")
check(WorldProgress.currentIndex(snapshots: w0) == 1, "current advances to world 1 after clearing world 0")

print("Introduction is scoped to the current world")
let planW = SessionPlanner.plan(snapshots: freshW, now: now, seed: 3)
let newWorlds = Set(planW.filter { $0.format == .recognition }.map { WorldCatalog.worldIndex(ofFact: $0.fact) })
check(newWorlds.isSubset(of: [0]), "fresh start only introduces world-0 facts (got \(newWorlds))")

print(failures == 0 ? "\nALL ENGINE TESTS PASSED" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
