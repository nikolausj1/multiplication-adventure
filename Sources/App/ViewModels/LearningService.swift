import Foundation
import SwiftData

/// Bridges SwiftData persistence to the pure engine: seeding, session planning,
/// answer recording, milestone detection, and dashboard aggregation.
@MainActor
struct LearningService {
    let context: ModelContext

    // MARK: Seeding

    /// Ensures the 91 facts and a single profile exist.
    func bootstrap() {
        let factCount = (try? context.fetchCount(FetchDescriptor<Fact>())) ?? 0
        if factCount == 0 {
            for id in FactUniverse.allFacts { context.insert(Fact(id)) }
        }
        if (try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0 == 0 {
            context.insert(Profile())
        }
        try? context.save()
    }

    func profile() -> Profile {
        if let p = try? context.fetch(FetchDescriptor<Profile>()).first { return p }
        let p = Profile(); context.insert(p); return p
    }

    func allFacts() -> [Fact] {
        (try? context.fetch(FetchDescriptor<Fact>())) ?? []
    }

    func fact(_ id: FactID) -> Fact? {
        let key = id.key
        return try? context.fetch(FetchDescriptor<Fact>(predicate: #Predicate { $0.key == key })).first
    }

    // MARK: Planning

    func buildSession(now: Date = .now, seed: UInt64? = nil) -> [PlannedQuestion] {
        let snaps = allFacts().map(\.snapshot)
        let s = seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970))
        return SessionPlanner.plan(snapshots: snaps, now: now, seed: s)
    }

    private func currentThreshold() -> Double {
        let times = allFacts().flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        return FluencyThreshold.current(recentFluencyTimes: times)
    }

    private func masteredCount() -> Int {
        allFacts().filter { $0.stage == .mastered }.count
    }

    // MARK: Recording an answer

    struct AnswerResult {
        var correct: Bool
        var xp: Int
        var becameMastered: Bool
        var celebration: Celebration?
    }

    func record(prompt: OrientedPrompt, format: MasteryStage, correct: Bool,
                responseTime: Double, now: Date = .now) -> AnswerResult {
        guard let factRow = fact(prompt.fact) else {
            return AnswerResult(correct: correct, xp: 0, becameMastered: false, celebration: nil)
        }
        let threshold = currentThreshold()
        let before = ProgressAggregate.from(snapshots: allFacts().map(\.snapshot),
                                            streakDays: profile().streakDays)

        let outcome = PromotionEngine.apply(to: factRow.snapshot, correct: correct,
                                            responseTime: responseTime,
                                            fluencyThreshold: threshold, now: now)
        factRow.apply(outcome.snapshot)

        let frac = Double(masteredCount()) / Double(FactUniverse.count)
        let xp = XPEngine.xp(correct: correct, responseTime: responseTime, stage: format,
                             fluencyThreshold: threshold, masteryFraction: frac)
        let p = profile()
        p.totalXP += xp

        let after = ProgressAggregate.from(snapshots: allFacts().map(\.snapshot),
                                           streakDays: p.streakDays)
        let events = MilestoneEngine.events(before: before, after: after)
        persistMilestones(events, now: now)
        // Only T2+ interrupts the loop with the celebration overlay.
        let celebration = MilestoneEngine.merge(events, minTier: .t2)

        try? context.save()
        return AnswerResult(correct: correct, xp: xp,
                            becameMastered: outcome.becameMastered, celebration: celebration)
    }

    // MARK: Finishing a session

    /// Writes the session record and updates the streak. Returns a streak celebration
    /// if a threshold was crossed (or a light ack otherwise).
    @discardableResult
    func finishSession(questionCount: Int, correctCount: Int, xpEarned: Int,
                       responseTimes: [Double], factsTouched: Int,
                       now: Date = .now) -> Celebration? {
        let p = profile()
        let beforeStreak = p.streakDays
        let newStreak = p.registerPractice(on: now)

        let median = Self.median(responseTimes)
        context.insert(SessionRecord(date: now, questionCount: questionCount,
                                     correctCount: correctCount, xpEarned: xpEarned,
                                     medianResponseTime: median, factsTouched: factsTouched))

        // Streak milestone (other dimensions unchanged here).
        let m = masteredCount()
        let base = ProgressAggregate(masteredCount: m, completedFactors: [],
                                     rankIndex: RankLadder.rank(forMasteredCount: m).index,
                                     streakDays: beforeStreak)
        var after = base; after.streakDays = newStreak
        let events = MilestoneEngine.events(before: base, after: after)
        persistMilestones(events.filter { $0.tier >= .t2 }, now: now)

        try? context.save()
        return MilestoneEngine.merge(events, minTier: .t1)
    }

    private func persistMilestones(_ events: [MilestoneEvent], now: Date) {
        for e in events where e.tier >= .t2 {
            let label: String
            switch e.kind {
            case .rankUp(let n): label = "Rank: \(n)"
            case .tableComplete(let f): label = "Table ×\(f)"
            case .overallPercent(let p): label = "\(p)% mastered"
            case .streakThreshold(let d): label = "\(d)-day streak"
            case .completion: label = "Completed!"
            default: continue
            }
            context.insert(MilestoneRecord(kindLabel: label, detail: e.message,
                                           tier: e.tier, earnedDate: now))
        }
    }

    static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count/2 - 1] + s[s.count/2]) / 2
    }
}
