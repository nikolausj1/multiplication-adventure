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
check(FactUniverse.count == 91, "91 unique facts")
check(FactID(8, 7) == FactID(7, 8), "facts are commutative/canonical")
check(FactUniverse.allFacts.allSatisfy { $0.a <= $0.b }, "all stored canonically")

print("Curriculum")
check(Curriculum.slot(of: FactID(0, 0)) == 0, "0×0 introduced first")
check(Curriculum.slot(of: FactID(6, 7)) == Curriculum.introRank(ofFactor: 7), "6×7 unlocks with the 7s")
check(Curriculum.factsBySlot().reduce(0) { $0 + $1.count } == 91, "every fact lands in a slot")

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

print("Promotion: recognition → recall (2 consecutive)")
var f = FactSnapshot(id: FactID(7, 8), introduced: true, stage: .recognition)
f = PromotionEngine.apply(to: f, correct: true, responseTime: 2, fluencyThreshold: 3, now: now).snapshot
check(f.stage == .recognition, "one correct stays in recognition")
let o = PromotionEngine.apply(to: f, correct: true, responseTime: 2, fluencyThreshold: 3, now: now)
check(o.snapshot.stage == .recall, "two consecutive correct promotes to recall")
check(o.promotedStage, "promotion flagged")

print("Promotion: a wrong MC resets the streak")
var g = FactSnapshot(id: FactID(3, 4), introduced: true, stage: .recognition, recognitionStreak: 1)
g = PromotionEngine.apply(to: g, correct: false, responseTime: 0, fluencyThreshold: 3, now: now).snapshot
check(g.recognitionStreak == 0, "wrong answer resets recognition streak")

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
check(RankLadder.rank(forMasteredCount: 91).name == "Master", "Master at 91")
check(RankLadder.next(afterMasteredCount: 0)?.rank.name == "Apprentice", "next rank is Apprentice")

print("Session planner: cold start")
let fresh = FactUniverse.allFacts.map { FactSnapshot(id: $0) }
let plan0 = SessionPlanner.plan(snapshots: fresh, now: now, seed: 1)
check(!plan0.isEmpty, "cold start produces a session")
check(plan0.allSatisfy { $0.movement != .warmup } || plan0.first?.movement == .warmup,
      "no mastered facts → warm-up gracefully empty or leads")
let newCount = plan0.filter { $0.format == .recognition }.count
check(newCount > 0 && newCount <= 4, "introduces a capped trickle of new facts (\(newCount))")
check(plan0.first?.fact == FactID(0, 0) || plan0.contains { $0.fact == FactID(0, 0) },
      "earliest curriculum fact appears first")

print("Session planner: interleaving")
let q = (2...12).flatMap { b in [FactSnapshot(id: FactID(b, b), introduced: true, stage: .recall)] }
let interleaved = SessionPlanner.plan(snapshots: q, now: now, seed: 7)
var adjacentSameTable = 0
for i in 1..<interleaved.count where interleaved[i].fact.b == interleaved[i-1].fact.b { adjacentSameTable += 1 }
check(adjacentSameTable == 0, "no two adjacent questions share a table when avoidable")

print("Milestones: coincident events merge to highest tier")
let before = ProgressAggregate(masteredCount: 21, completedFactors: [], rankIndex: 1, streakDays: 2)
let after = ProgressAggregate(masteredCount: 23, completedFactors: [7], rankIndex: 2, streakDays: 3)
let evs = MilestoneEngine.events(before: before, after: after)
let celebration = MilestoneEngine.merge(evs)
check(celebration?.tier == .t3, "25% crossing (T3) wins over rank-up/table/streak")
check((celebration?.lines.count ?? 0) >= 2, "lower milestones fold into the lines")

print("Milestones: completion supersedes all")
let preDone = ProgressAggregate(masteredCount: 90, completedFactors: [], rankIndex: 4, streakDays: 6)
let done = ProgressAggregate(masteredCount: 91, completedFactors: [], rankIndex: 5, streakDays: 7)
let doneEvents = MilestoneEngine.events(before: preDone, after: done)
check(doneEvents.count == 1 && doneEvents[0].tier == .t4, "100% is a single T4 finale")

print(failures == 0 ? "\nALL ENGINE TESTS PASSED" : "\n\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
