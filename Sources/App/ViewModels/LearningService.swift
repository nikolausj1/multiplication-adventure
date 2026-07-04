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
        profile.clearedWorldsMask = 0
        profile.bestSpeedAvg = 0
        seedFacts(for: profile)
        try? context.save()
    }

    /// Debug only (launch-arg gated): seed progress so map/speed/certificate states can be
    /// previewed without playing through. `complete` masters everything.
    func applyDemoProgress(complete: Bool) {
        let p = activeProfile()
        let now = Date()
        // Bosses count as beaten for the demo-cleared worlds.
        for w in 0..<WorldCatalog.count where complete || w <= 2 { p.markWorldCleared(w) }
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
        return SessionPlanner.plan(snapshots: snaps, now: now, seed: s,
                                   clearedWorlds: activeProfile().clearedWorlds)
    }

    // MARK: Star Quest planning

    /// The day's quest: drill the facts of the current world's NEXT star through
    /// their whole ladder (2 MC + 3 typed, spaced by review questions), woven with
    /// cumulative review. The session ends when the star lands (see the VM), so
    /// "one quest ≈ one star" by construction. When the world is boss-pending
    /// (all fluent), returns a classic review session and an empty batch.
    func buildQuestSession(now: Date = .now, seed: UInt64? = nil)
        -> (queue: [PlannedQuestion], batch: [FactID]) {
        let p = activeProfile()
        let snaps = facts().map(\.snapshot)
        let byID = Dictionary(uniqueKeysWithValues: snaps.map { ($0.id, $0) })
        let idx = WorldProgress.currentIndex(snapshots: snaps, cleared: p.clearedWorlds)
        let worldFacts = WorldCatalog.facts(inWorld: idx)
            .sorted { (Curriculum.slot(of: $0), $0.b, $0.a) < (Curriculum.slot(of: $1), $1.b, $1.a) }
        let fluentCount = worldFacts.filter { (byID[$0]?.stage ?? .recognition) >= .fluency }.count
        let total = worldFacts.count

        // Boss-pending (or all worlds cleared): review-only session, no batch.
        // Mastered facts still get the occasional inverse form here — this is the
        // Master Quest era's main diet.
        guard total > 0, fluentCount < total else {
            var qs = SessionPlanner.plan(snapshots: snaps, now: now,
                                         seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)),
                                         clearedWorlds: p.clearedWorlds)
            let mastered = Set(snaps.filter { $0.stage == .mastered }.map(\.id))
            if mastered.count >= Self.missingFactorMinMastered {
                var mfRng = SplitMix64(seed: (seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970))) &+ 7)
                qs = qs.map { q in
                    guard q.movement != .warmup, mastered.contains(q.fact),
                          mfRng.next() % Self.missingFactorDenominator == 0 else { return q }
                    return PlannedQuestion(prompt: q.prompt, format: .recall, movement: q.movement,
                                           options: nil, timed: false, missingFactor: true)
                }
            }
            return (qs, [])
        }

        let filledStars = WorldStars.filled(fluent: fluentCount, total: total)
        let nextThreshold = Int(ceil(Double(total) * Double(filledStars + 1) / Double(WorldStars.starCount)))
        let needed = max(1, nextThreshold - fluentCount)

        // Today's batch: half-climbed leftovers first, then fresh facts in slot order.
        let notFluent = worldFacts.filter { (byID[$0]?.stage ?? .recognition) < .fluency }
        let leftovers = notFluent.filter { byID[$0]?.introduced ?? false }
        let fresh = notFluent.filter { !(byID[$0]?.introduced ?? false) }
        let batch = Array((leftovers + fresh).prefix(needed))

        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        let queue = assembleQuest(batch: batch, byID: byID, snaps: snaps, now: now, rng: &rng)
        return (queue, batch)
    }

    /// More reps for batch facts that haven't reached fluent (miss recovery),
    /// woven with a few fresh reviews. Empty when the batch is done.
    func questExtension(batch: [FactID], now: Date = .now) -> [PlannedQuestion] {
        let snaps = facts().map(\.snapshot)
        let byID = Dictionary(uniqueKeysWithValues: snaps.map { ($0.id, $0) })
        let remaining = batch.filter { (byID[$0]?.stage ?? .recognition) < .fluency }
        guard !remaining.isEmpty else { return [] }
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(now.timeIntervalSince1970)) &+ 99)
        return assembleQuest(batch: remaining, byID: byID, snaps: snaps, now: now,
                             rng: &rng, reviewTarget: 4)
    }

    /// Ladder completion of a fact toward fluent, in [0, 1] (5 total rungs).
    func ladderProgress(_ id: FactID) -> Double {
        guard let s = fact(id)?.snapshot else { return 0 }
        if s.stage >= .fluency { return 1 }
        let done = s.stage == .recall ? 2 + min(s.recallCorrect, 3) : min(s.recognitionStreak, 2)
        return Double(done) / 5.0
    }

    /// Missing-factor review: 1 question in `missingFactorDenominator` (mastered
    /// facts only, once the mastered pool is deep enough). Static so a debug launch
    /// arg can force it for previews.
    static var missingFactorDenominator: UInt64 = 6
    static let missingFactorMinMastered = 15

    /// Builds the quest in three phases so the input mode never thrashes:
    /// WARM-UP (typed review) → MEET (all multiple-choice for today's new facts)
    /// → TRAIN (typed: batch reps woven with cumulative review).
    private func assembleQuest(batch: [FactID], byID: [FactID: FactSnapshot],
                               snaps: [FactSnapshot], now: Date,
                               rng: inout SplitMix64, reviewTarget: Int = 25) -> [PlannedQuestion] {
        let fluencyTimes = snaps.flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        let threshold = FluencyThreshold.current(recentFluencyTimes: fluencyTimes)
        let masteredCount = snaps.filter { $0.stage == .mastered }.count

        func question(_ id: FactID, format: MasteryStage, movement: SessionMovement,
                      missingFactor: Bool = false) -> PlannedQuestion {
            let prompt = OrientedPrompt(fact: id, swapped: (rng.next() & 1) == 1)
            let options = format == .recognition
                ? DistractorGenerator.options(for: prompt, seed: rng.next()) : nil
            return PlannedQuestion(prompt: prompt, format: format, movement: movement,
                                   options: options, timed: format == .fluency && !missingFactor,
                                   missingFactor: missingFactor)
        }

        // Ladder reps per batch fact, split by input mode.
        var mcReps: [[PlannedQuestion]] = []
        var typedReps: [[PlannedQuestion]] = []
        for id in batch {
            let s = byID[id]
            let stage = s?.stage ?? .recognition
            if stage == .recognition || !(s?.introduced ?? false) {
                let mcLeft = max(0, 2 - (s?.recognitionStreak ?? 0))
                mcReps.append((0..<mcLeft).map { _ in question(id, format: .recognition, movement: .core) })
                typedReps.append((0..<3).map { _ in question(id, format: .recall, movement: .core) })
            } else {
                mcReps.append([])
                let left = max(1, 3 - (s?.recallCorrect ?? 0))
                typedReps.append((0..<left).map { _ in question(id, format: .recall, movement: .core) })
            }
        }

        // Cumulative review pool by priority; mastered facts occasionally arrive in
        // inverse form ("3 × ? = 12") once his mastered pool is deep enough.
        // Recognition-stage facts are excluded: their reviews would be multiple-
        // choice, breaking the one-input-mode-per-phase promise. They rejoin as
        // batch facts within a day or two anyway.
        let batchSet = Set(batch)
        let reviewSnaps = snaps
            .filter { $0.introduced && $0.stage >= .recall && !batchSet.contains($0.id) }
            .sorted { PriorityCalculator.priority(of: $0, now: now, fluencyThreshold: threshold)
                    > PriorityCalculator.priority(of: $1, now: now, fluencyThreshold: threshold) }
            .prefix(reviewTarget)
        var reviews = reviewSnaps.map { s in
            if s.stage == .mastered, masteredCount >= Self.missingFactorMinMastered,
               rng.next() % Self.missingFactorDenominator == 0 {
                return question(s.id, format: .recall, movement: .review, missingFactor: true)
            }
            return question(s.id, format: s.stage == .mastered ? .fluency : s.stage, movement: .review)
        }.makeIterator()

        var queue: [PlannedQuestion] = []
        // WARM-UP: two easy typed reviews to get hands moving.
        for _ in 0..<2 {
            if let r = reviews.next() {
                queue.append(PlannedQuestion(prompt: r.prompt, format: r.format,
                                             movement: .warmup, options: r.options,
                                             timed: r.timed, missingFactor: false))
            }
        }
        // MEET: all of today's multiple-choice, facts alternating.
        let mcMax = mcReps.map(\.count).max() ?? 0
        for round in 0..<mcMax {
            for factReps in mcReps where round < factReps.count { queue.append(factReps[round]) }
        }
        // TRAIN: typed batch reps round-robin, a review between for spacing.
        let typedMax = typedReps.map(\.count).max() ?? 0
        for round in 0..<typedMax {
            for factReps in typedReps where round < factReps.count {
                queue.append(factReps[round])
                if let r = reviews.next() { queue.append(r) }
            }
        }
        // Top up with review so a quest is never a drive-by (floor ~15 where possible).
        while queue.count < 15, let r = reviews.next() { queue.append(r) }
        return queue
    }

    private func currentThreshold() -> Double {
        let times = facts().flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        return FluencyThreshold.current(recentFluencyTimes: times)
    }

    /// Facts at Fluency or Mastered — gates the Speed Round (count-up + beat-your-best).
    func fluentPlusCount() -> Int { facts().filter { $0.stage >= .fluency }.count }

    /// The current fast-answer bar (boss crit-hits compare against this).
    func fluencyThresholdNow() -> Double { currentThreshold() }

    /// Fluent-progress of the current world (for wrap-screen "how close am I" UI).
    func currentWorldStat() -> (index: Int, fluent: Int, total: Int) {
        let snaps = facts().map(\.snapshot)
        let idx = WorldProgress.currentIndex(snapshots: snaps, cleared: activeProfile().clearedWorlds)
        let stat = WorldProgress.stats(snapshots: snaps)[safe: idx]
        return (idx, stat?.fluentPlus ?? 0, stat?.total ?? 0)
    }

    /// Fluent-progress of a specific world (the in-session ring pins the world the
    /// session started in, even if it clears mid-session).
    func worldStat(at index: Int) -> (fluent: Int, total: Int) {
        let stat = WorldProgress.stats(snapshots: facts().map(\.snapshot))[safe: index]
        return (stat?.fluentPlus ?? 0, stat?.total ?? 0)
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

    /// The world's boss challenge: a timed round over that world's own facts.
    /// 10–16 questions (small worlds repeat facts in fresh orientations).
    func buildBossSession(worldIndex: Int, now: Date = .now, seed: UInt64? = nil) -> [PlannedQuestion] {
        let ids = WorldCatalog.facts(inWorld: worldIndex)
        guard !ids.isEmpty else { return [] }
        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        let target = min(max(ids.count, 10), 16)
        var picks: [FactID] = []
        while picks.count < target {
            var round = ids
            round.shuffle(using: &rng)
            picks.append(contentsOf: round.prefix(target - picks.count))
        }
        return picks.map { id in
            let prompt = OrientedPrompt(fact: id, swapped: (rng.next() & 1) == 1)
            return PlannedQuestion(prompt: prompt, format: .fluency, movement: .core,
                                   options: nil, timed: true)
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
        var becameFluent: Bool     // reached Fluency — fills the world ring
        var becameMastered: Bool
        var celebration: Celebration?
    }

    func record(prompt: OrientedPrompt, format: MasteryStage, correct: Bool,
                responseTime: Double, countsTime: Bool = true, now: Date = .now) -> AnswerResult {
        let p = activeProfile()
        guard let factRow = fact(prompt.fact) else {
            return AnswerResult(correct: correct, xp: 0, becameFluent: false,
                                becameMastered: false, celebration: nil)
        }
        let threshold = currentThreshold()
        var before = ProgressAggregate.from(snapshots: facts().map(\.snapshot), streakDays: p.streakDays)
        before.clearedWorlds = p.clearedWorlds.count   // clears come from boss wins, not fluency

        let outcome = PromotionEngine.apply(to: factRow.snapshot, correct: correct,
                                            responseTime: responseTime,
                                            fluencyThreshold: threshold, now: now,
                                            countsTime: countsTime)
        factRow.apply(outcome.snapshot)

        let frac = Double(masteredCount()) / Double(FactUniverse.count)
        let xp = XPEngine.xp(correct: correct, responseTime: responseTime, stage: format,
                             fluencyThreshold: threshold, masteryFraction: frac)
        p.totalXP += xp

        var after = ProgressAggregate.from(snapshots: facts().map(\.snapshot), streakDays: p.streakDays)
        after.clearedWorlds = p.clearedWorlds.count
        let events = MilestoneEngine.events(before: before, after: after)
        persistMilestones(events, for: p, now: now)
        let celebration = MilestoneEngine.merge(events, minTier: .t2)

        try? context.save()
        return AnswerResult(correct: correct, xp: xp,
                            becameFluent: outcome.promotedStage && outcome.snapshot.stage == .fluency,
                            becameMastered: outcome.becameMastered, celebration: celebration)
    }

    // MARK: Finishing a session

    /// Accuracy required to beat a world's boss challenge. Forgiving on purpose:
    /// the boss is a climax, not a wall — misses just mean "train and retry".
    static let bossPassAccuracy = 0.85

    @discardableResult
    func finishSession(questionCount: Int, correctCount: Int, xpEarned: Int,
                       responseTimes: [Double], factsTouched: Int,
                       speed: Bool = false, bossWorld: Int? = nil,
                       practiced: Bool = true, now: Date = .now) -> Celebration? {
        let p = activeProfile()
        let beforeStreak = p.streakDays
        // The flame is strict: only real completed work lights it (quest star landed,
        // rollover effort, boss, speed) — never a two-answer drive-by or a dev jump.
        let newStreak = practiced ? p.registerPractice(on: now) : p.streakDays

        let median = Self.median(responseTimes)

        // Boss challenge: pass ⇒ the world clears (T3 moment); fail costs nothing.
        if let bossWorld {
            let rec = SessionRecord(date: now, questionCount: questionCount, correctCount: correctCount,
                                    xpEarned: xpEarned, medianResponseTime: median, factsTouched: factsTouched)
            rec.profile = p
            context.insert(rec)
            let accuracy = questionCount == 0 ? 0 : Double(correctCount) / Double(questionCount)
            let world = WorldCatalog.worlds[safe: bossWorld]
            let name = world?.name ?? "World \(bossWorld + 1)"
            let boss = world?.bossName ?? "Guardian"
            if accuracy >= Self.bossPassAccuracy, !p.clearedWorlds.contains(bossWorld) {
                p.markWorldCleared(bossWorld)
                let milestone = MilestoneRecord(kindLabel: "Cleared \(name)",
                                                detail: "Defeated the \(boss)", tier: .t3, earnedDate: now)
                milestone.profile = p
                context.insert(milestone)
                try? context.save()
                return Celebration(tier: .t3, headline: "\(name) cleared!",
                                   lines: ["The \(boss) has fallen — the trail continues!"])
            }
            try? context.save()
            return nil   // wrap shows the encouraging retry state
        }

        // Speed Round: track beat-your-best on median response time.
        if speed, median > 0 {
            let isBest = p.bestSpeedAvg == 0 || median < p.bestSpeedAvg
            if isBest { p.bestSpeedAvg = median }
            let rec = SessionRecord(date: now, questionCount: questionCount, correctCount: correctCount,
                                    xpEarned: xpEarned, medianResponseTime: median, factsTouched: factsTouched)
            rec.profile = p
            context.insert(rec)
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
        let base = ProgressAggregate(masteredCount: m, completedFactors: [],
                                     clearedWorlds: p.clearedWorlds.count, streakDays: beforeStreak)
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
