import Foundation
import SwiftData

/// Bridges SwiftData persistence to the pure engine, scoped to the active profile:
/// seeding, profile management, session planning, answer recording, milestones.
@MainActor
struct LearningService {
    let context: ModelContext

    // MARK: Bootstrap & profiles

    func bootstrap() {
        let profiles = allProfiles()
        if profiles.isEmpty {
            let p = Profile(name: "Player 1", isActive: true)
            context.insert(p)
            seedFacts(for: p)
        } else {
            if !profiles.contains(where: { $0.isActive }) { profiles[0].isActive = true }
            for p in profiles where p.facts.isEmpty { seedFacts(for: p) }
        }
        try? context.save()
    }

    func allProfiles() -> [Profile] {
        (try? context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func activeProfile() -> Profile {
        if let a = allProfiles().first(where: { $0.isActive }) { return a }
        if let f = allProfiles().first { f.isActive = true; try? context.save(); return f }
        let p = Profile(); context.insert(p); seedFacts(for: p); try? context.save(); return p
    }

    func seedFacts(for profile: Profile) {
        for id in FactUniverse.allFacts {
            let f = Fact(id); f.profile = profile; context.insert(f)
        }
    }

    @discardableResult
    func createProfile(name: String, avatar: String) -> Profile {
        for p in allProfiles() { p.isActive = false }
        let p = Profile(name: name.isEmpty ? "Player \(allProfiles().count + 1)" : name,
                        avatarSymbol: avatar, isActive: true)
        context.insert(p); seedFacts(for: p); try? context.save(); return p
    }

    func switchTo(_ profile: Profile) {
        for p in allProfiles() { p.isActive = (p.id == profile.id) }
        try? context.save()
    }

    func rename(_ profile: Profile, to name: String) {
        profile.name = name; try? context.save()
    }

    /// Never deletes the last profile. Deleting the active one promotes another.
    func delete(_ profile: Profile) {
        guard allProfiles().count > 1 else { return }
        let wasActive = profile.isActive
        context.delete(profile)
        if wasActive, let other = allProfiles().first { other.isActive = true }
        try? context.save()
    }

    /// Wipes a profile back to brand-new (re-seeds its 91 facts).
    func resetProgress(_ profile: Profile) {
        for f in profile.facts { context.delete(f) }
        for s in profile.sessions { context.delete(s) }
        for m in profile.milestones { context.delete(m) }
        profile.totalXP = 0
        profile.streakDays = 0
        profile.lastPracticeDate = nil
        profile.speedRoundUnlocked = false
        seedFacts(for: profile)
        try? context.save()
    }

    /// Debug only (launch-arg gated): seed progress so map/speed/certificate states can be
    /// previewed without playing through. `complete` masters everything.
    func applyDemoProgress(complete: Bool) {
        let p = activeProfile()
        let now = Date()
        for f in p.facts {
            let w = WorldCatalog.worldIndex(ofFact: f.id)
            if complete || w <= 2 {
                f.introduced = true; f.stageRaw = MasteryStage.mastered.rawValue; f.box = 5
                f.masteredDate = now; f.totalAttempts = 6; f.totalCorrect = 6
                f.recentTimes = [1.2, 1.0, 1.1]; f.averageTime = 1.1
                f.fluencyFastCount = 3; f.fluencyFastDays = [20240101, 20240102]
            } else if w == 3 {
                // Partial current world so a node stays "current".
                let fluent = (f.a + f.b).isMultiple(of: 2)
                f.introduced = true
                f.stageRaw = (fluent ? MasteryStage.fluency : MasteryStage.recall).rawValue
                f.box = 3; f.totalAttempts = 4; f.totalCorrect = 4
                f.recentTimes = [1.6]; f.averageTime = 1.6
            }
        }
        try? context.save()
    }

    // MARK: Active-profile facts

    private func facts() -> [Fact] { activeProfile().facts }
    func fact(_ id: FactID) -> Fact? { facts().first { $0.id == id } }

    // MARK: Planning

    func buildSession(now: Date = .now, seed: UInt64? = nil) -> [PlannedQuestion] {
        let snaps = facts().map(\.snapshot)
        let s = seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970))
        return SessionPlanner.plan(snapshots: snaps, now: now, seed: s)
    }

    private func currentThreshold() -> Double {
        let times = facts().flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        return FluencyThreshold.current(recentFluencyTimes: times)
    }

    /// Facts at Fluency or Mastered — gates the Speed Round (count-up + beat-your-best).
    func fluentPlusCount() -> Int { facts().filter { $0.stage >= .fluency }.count }

    /// Fluent-progress of the current world (for wrap-screen "how close am I" UI).
    func currentWorldStat() -> (index: Int, fluent: Int, total: Int) {
        let snaps = facts().map(\.snapshot)
        let idx = WorldProgress.currentIndex(snapshots: snaps)
        let stat = WorldProgress.stats(snapshots: snaps)[safe: idx]
        return (idx, stat?.fluentPlus ?? 0, stat?.total ?? 0)
    }

    /// Dev/testing: a session of a specific world's facts forced into one format,
    /// ignoring progression gating so any world/round is reachable immediately.
    func buildTestSession(worldIndex: Int, format: MasteryStage,
                          now: Date = .now, seed: UInt64? = nil) -> [PlannedQuestion] {
        let ids = WorldCatalog.facts(inWorld: worldIndex)
        guard !ids.isEmpty else { return [] }
        let fmt: MasteryStage = (format == .mastered) ? .fluency : format
        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        var pool = ids; pool.shuffle(using: &rng)
        return pool.prefix(12).map { id in
            let prompt = OrientedPrompt(fact: id, swapped: (rng.next() & 1) == 1)
            let options = fmt == .recognition ? DistractorGenerator.options(for: prompt, seed: rng.next()) : nil
            return PlannedQuestion(prompt: prompt, format: fmt, movement: .core,
                                   options: options, timed: fmt == .fluency)
        }
    }

    /// A timed round drawn only from already-fluent facts, all open-response.
    func buildSpeedSession(now: Date = .now, seed: UInt64? = nil) -> [PlannedQuestion] {
        let pool = facts().filter { $0.stage >= .fluency }.map(\.id)
        guard !pool.isEmpty else { return [] }
        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        var ids = pool; ids.shuffle(using: &rng)
        return ids.prefix(20).map { id in
            let prompt = OrientedPrompt(fact: id, swapped: (rng.next() & 1) == 1)
            return PlannedQuestion(prompt: prompt, format: .fluency, movement: .review,
                                   options: nil, timed: true)
        }
    }

    private func masteredCount() -> Int { facts().filter { $0.stage == .mastered }.count }

    // MARK: Recording an answer

    struct AnswerResult {
        var correct: Bool
        var xp: Int
        var becameMastered: Bool
        var celebration: Celebration?
    }

    func record(prompt: OrientedPrompt, format: MasteryStage, correct: Bool,
                responseTime: Double, now: Date = .now) -> AnswerResult {
        let p = activeProfile()
        guard let factRow = fact(prompt.fact) else {
            return AnswerResult(correct: correct, xp: 0, becameMastered: false, celebration: nil)
        }
        let threshold = currentThreshold()
        let before = ProgressAggregate.from(snapshots: facts().map(\.snapshot), streakDays: p.streakDays)

        let outcome = PromotionEngine.apply(to: factRow.snapshot, correct: correct,
                                            responseTime: responseTime,
                                            fluencyThreshold: threshold, now: now)
        factRow.apply(outcome.snapshot)

        let frac = Double(masteredCount()) / Double(FactUniverse.count)
        let xp = XPEngine.xp(correct: correct, responseTime: responseTime, stage: format,
                             fluencyThreshold: threshold, masteryFraction: frac)
        p.totalXP += xp

        let after = ProgressAggregate.from(snapshots: facts().map(\.snapshot), streakDays: p.streakDays)
        let events = MilestoneEngine.events(before: before, after: after)
        persistMilestones(events, for: p, now: now)
        let celebration = MilestoneEngine.merge(events, minTier: .t2)

        try? context.save()
        return AnswerResult(correct: correct, xp: xp,
                            becameMastered: outcome.becameMastered, celebration: celebration)
    }

    // MARK: Finishing a session

    @discardableResult
    func finishSession(questionCount: Int, correctCount: Int, xpEarned: Int,
                       responseTimes: [Double], factsTouched: Int,
                       speed: Bool = false, now: Date = .now) -> Celebration? {
        let p = activeProfile()
        let beforeStreak = p.streakDays
        let newStreak = p.registerPractice(on: now)

        let median = Self.median(responseTimes)

        // Speed Round: track beat-your-best on median response time.
        if speed, median > 0 {
            let isBest = p.bestSpeedAvg == 0 || median < p.bestSpeedAvg
            if isBest { p.bestSpeedAvg = median }
            let rec = SessionRecord(date: now, questionCount: questionCount, correctCount: correctCount,
                                    xpEarned: xpEarned, medianResponseTime: median, factsTouched: factsTouched)
            rec.profile = p
            context.insert(rec)
            p.registerPractice(on: now)
            try? context.save()
            return Celebration(tier: isBest ? .t2 : .t1,
                               headline: isBest ? "New best time!" : "Speed Round complete!",
                               lines: [String(format: "%.1fs average", median)])
        }
        let rec = SessionRecord(date: now, questionCount: questionCount,
                                correctCount: correctCount, xpEarned: xpEarned,
                                medianResponseTime: median, factsTouched: factsTouched)
        rec.profile = p
        context.insert(rec)

        let m = masteredCount()
        let cleared = WorldProgress.clearedCount(snapshots: facts().map(\.snapshot))
        let base = ProgressAggregate(masteredCount: m, completedFactors: [],
                                     clearedWorlds: cleared, streakDays: beforeStreak)
        var after = base; after.streakDays = newStreak
        let events = MilestoneEngine.events(before: base, after: after)
        persistMilestones(events.filter { $0.tier >= .t2 }, for: p, now: now)

        try? context.save()
        return MilestoneEngine.merge(events, minTier: .t1)
    }

    private func persistMilestones(_ events: [MilestoneEvent], for profile: Profile, now: Date) {
        for e in events where e.tier >= .t2 {
            let label: String
            switch e.kind {
            case .worldCleared(let n): label = "Cleared \(n)"
            case .tableComplete(let f): label = "Table ×\(f)"
            case .overallPercent(let p): label = "\(p)% mastered"
            case .streakThreshold(let d): label = "\(d)-day streak"
            case .completion: label = "Completed!"
            default: continue
            }
            let rec = MilestoneRecord(kindLabel: label, detail: e.message, tier: e.tier, earnedDate: now)
            rec.profile = profile
            context.insert(rec)
        }
    }

    static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count/2 - 1] + s[s.count/2]) / 2
    }
}
