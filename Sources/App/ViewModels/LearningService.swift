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
            // Migration heal: a profile with real progress predates onboarding —
            // never re-onboard it.
            for p in profiles where !p.onboarded && (p.totalXP > 0 || !p.sessions.isEmpty) {
                p.onboarded = true
            }
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
        p.onboarded = true   // parent-created profiles skip the kid onboarding
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

    /// Wipes a profile back to brand-new (re-seeds its facts).
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
        profile.questStars = 0
        profile.seenWorldIntrosMask = 0
        profile.pausedQuestDate = nil
        profile.pausedQuestElapsed = 0
        profile.pausedQuestMeter = 0
        profile.pausedQuestNewCount = 0
        seedFacts(for: profile)
        try? context.save()
    }

    /// Full "hand the app to a new kid" wipe: progress AND identity, and the
    /// first-run onboarding plays again.
    func startOver(_ profile: Profile) {
        resetProgress(profile)
        profile.name = "Player 1"
        profile.avatarSymbol = "avatar1"
        profile.grade = ""
        profile.onboarded = false
        try? context.save()
    }

    /// Debug only (launch-arg gated): seed progress so map/speed/certificate states can be
    /// previewed without playing through. `complete` masters everything.
    func applyDemoProgress(complete: Bool) {
        let p = activeProfile()
        let now = Date()
        p.onboarded = true   // demo jumps never trip the first-run gate
        // Bosses count as beaten for the demo-cleared worlds; stars match.
        for w in 0..<WorldCatalog.count where complete || w <= 2 { p.markWorldCleared(w) }
        p.questStars = complete ? 5 * WorldCatalog.count : 17   // 3 cleared + 2 in world 4
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
                // A few genuinely-struggled facts so Trouble Spots has data.
                if (f.a &+ f.b) % 7 == 0, min(f.a, f.b) > 1 {
                    f.totalAttempts = 8; f.totalCorrect = 4
                }
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
    func buildDailyQuest(now: Date = .now, seed: UInt64? = nil)
        -> (queue: [PlannedQuestion], batch: [FactID]) {
        let snaps = facts().map(\.snapshot)
        let byID = Dictionary(uniqueKeysWithValues: snaps.map { ($0.id, $0) })
        let batch = frontierBatch(byID: byID, exclude: [], size: 4)
        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        // Empty batch (everything fluent) still builds: warm-up + review + MF —
        // the Master Quest era's diet.
        let queue = assembleQuest(batch: batch, byID: byID, snaps: snaps, now: now, rng: &rng)
        return (queue, batch)
    }

    /// The next facts up the GLOBAL curriculum: leftovers (introduced, sub-fluent)
    /// first, then fresh — drip-mixed across the two nearest active tables so a
    /// batch never runs one table. `maxFresh` is the novelty budget's remaining
    /// allowance: leftovers are free, brand-new introductions are rationed.
    private func frontierBatch(byID: [FactID: FactSnapshot], exclude: Set<FactID>,
                               size: Int, maxFresh: Int = .max) -> [FactID] {
        let remaining = FactUniverse.allFacts.filter {
            !exclude.contains($0) && (byID[$0]?.stage ?? .recognition) < .fluency
        }
        guard !remaining.isEmpty else { return [] }
        let slots = Array(Set(remaining.map { Curriculum.slot(of: $0) }).sorted().prefix(2))
        let window = Self.dripOrder(remaining.filter { slots.contains(Curriculum.slot(of: $0)) })
        let leftovers = window.filter { byID[$0]?.introduced ?? false }
        let fresh = window.filter { !(byID[$0]?.introduced ?? false) }.prefix(max(0, maxFresh))
        return Array((leftovers + fresh).prefix(size))
    }

    /// Whether a fact has ever been served (the novelty budget counts the rest).
    func isIntroduced(_ id: FactID) -> Bool { fact(id)?.introduced ?? false }

    // MARK: Paused quest (X = pause for the day)

    func savePausedQuest(elapsed: Double, meter: Double, newCount: Int, now: Date = .now) {
        let p = activeProfile()
        p.pausedQuestDate = now
        p.pausedQuestElapsed = elapsed
        p.pausedQuestMeter = meter
        p.pausedQuestNewCount = newCount
        try? context.save()
    }

    /// Today's paused quest, if any (stale ones are cleared). Loading does NOT
    /// clear it — completion does, so a crash can't eat progress.
    func loadPausedQuest(now: Date = .now) -> (elapsed: Double, meter: Double, newCount: Int)? {
        let p = activeProfile()
        guard let date = p.pausedQuestDate else { return nil }
        guard Calendar.current.isDate(date, inSameDayAs: now) else {
            clearPausedQuest()
            return nil
        }
        return (p.pausedQuestElapsed, p.pausedQuestMeter, p.pausedQuestNewCount)
    }

    func clearPausedQuest() {
        let p = activeProfile()
        p.pausedQuestDate = nil
        p.pausedQuestElapsed = 0
        p.pausedQuestMeter = 0
        p.pausedQuestNewCount = 0
        try? context.save()
    }

    /// Map hint: is there a resumable quest right now?
    func hasPausedQuest(now: Date = .now) -> Bool {
        guard let d = activeProfile().pausedQuestDate else { return false }
        return Calendar.current.isDate(d, inSameDayAs: now)
    }

    /// Mid-session: the batch is done but the clock isn't — chain the next
    /// frontier batch (full ladder: cards then typed) with a few fresh reviews.
    /// `maxFresh` = how many brand-new facts the session may still introduce.
    func chainBatch(exclude: Set<FactID>, maxFresh: Int = .max, now: Date = .now)
        -> (queue: [PlannedQuestion], batch: [FactID]) {
        let snaps = facts().map(\.snapshot)
        let byID = Dictionary(uniqueKeysWithValues: snaps.map { ($0.id, $0) })
        let batch = frontierBatch(byID: byID, exclude: exclude, size: 3, maxFresh: maxFresh)
        guard !batch.isEmpty else { return ([], []) }
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(now.timeIntervalSince1970)) &+ 51)
        let queue = assembleQuest(batch: batch, byID: byID, snaps: snaps, now: now,
                                  rng: &rng, reviewTarget: 6, includeWarmup: false)
        return (queue, batch)
    }

    // MARK: Stars & worlds (session trophies — decoupled from fluency)

    func starsInCurrentWorld() -> Int { activeProfile().starsInCurrentWorld }
    func currentWorldIdx() -> Int { activeProfile().currentWorldIndex }

    /// Award the completed session's star; returns its 0-based socket, or nil
    /// when the world is full (boss pending). Persisted immediately.
    func awardQuestStar() -> Int? {
        let socket = activeProfile().awardQuestStar()
        try? context.save()
        return socket
    }

    /// The world's facts in "drip order": round-robin across the world's tables
    /// so star batches mix (0×3, 0×4, 1×3 — never nine ×3s in a row).
    static func dripOrder(_ facts: [FactID]) -> [FactID] {
        let bySlot = Dictionary(grouping: facts) { Curriculum.slot(of: $0) }
        let columns = bySlot.keys.sorted().map { s in
            bySlot[s]!.sorted { ($0.b, $0.a) < ($1.b, $1.a) }
        }
        var out: [FactID] = []
        var row = 0
        while out.count < facts.count {
            for col in columns where row < col.count { out.append(col[row]) }
            row += 1
        }
        return out
    }

    /// A pure review round: fills remaining session clock when no new facts are
    /// left to chain (the all-fluent endgame). Weak-first, fluent+ only, MF mixed
    /// in; the per-session serve cap (reviewExclude) stops a small pool cycling.
    func reviewRound(reviewExclude: Set<FactID> = [], now: Date = .now) -> [PlannedQuestion] {
        let snaps = facts().map(\.snapshot)
        let threshold = FluencyThreshold.current(
            recentFluencyTimes: snaps.flatMap { $0.stage >= .fluency ? $0.recentTimes : [] })
        let fluentTotal = snaps.filter { $0.stage >= .fluency }.count
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(now.timeIntervalSince1970)) &+ 33)
        var queue: [PlannedQuestion] = []
        let reviews = snaps
            .filter { $0.introduced && $0.stage >= .fluency && !reviewExclude.contains($0.id)
                    && min($0.id.a, $0.id.b) > 1 }   // rule facts (×0/×1) never need review
            .sorted { Self.reviewWeight($0, now: now, threshold: threshold)
                    > Self.reviewWeight($1, now: now, threshold: threshold) }
            .prefix(10)
        for s in reviews {
            let prompt = OrientedPrompt(fact: s.id, swapped: (rng.next() & 1) == 1)
            if s.stage >= .fluency, s.id.a != 0, fluentTotal >= Self.missingFactorMinFluent,
               rng.next() % (s.stage == .mastered ? 2 : Self.missingFactorDenominator) == 0 {
                queue.append(PlannedQuestion(prompt: prompt, format: .recall,
                                             movement: .review, options: nil,
                                             timed: false, missingFactor: true))
            } else {
                queue.append(PlannedQuestion(
                    prompt: prompt, format: s.stage == .mastered ? .fluency : s.stage,
                    movement: .review, options: nil, timed: s.stage >= .fluency))
            }
        }
        return Self.antiRepeat(queue)
    }

    /// Review priority with the hard-table boost: ×6/×7/×8 facts (his weak
    /// tables) weigh 1.5× so they dominate reviews — and boss picks — once met.
    static func reviewWeight(_ s: FactSnapshot, now: Date, threshold: Double) -> Double {
        let p = PriorityCalculator.priority(of: s, now: now, fluencyThreshold: threshold)
        let hard = [6, 7, 8].contains(s.id.a) || [6, 7, 8].contains(s.id.b)
        return hard ? p * 1.5 : p
    }

    /// No answer three times in a row, and repeats spaced out — kills the
    /// "the answer is 1 nine times" feel. Swaps stay within a format+movement
    /// so phase blocks (and the bar's color contract) survive.
    static func antiRepeat(_ q: [PlannedQuestion]) -> [PlannedQuestion] {
        var qs = q
        guard qs.count > 1 else { return qs }
        // Pass 1: never the same fact twice in a row (best-effort swap forward
        // within the same format+movement so phase blocks survive).
        for i in 1..<qs.count where qs[i].fact == qs[i - 1].fact {
            var j = i + 1
            while j < qs.count,
                  !(qs[j].fact != qs[i - 1].fact
                    && (qs[j].format == .recognition) == (qs[i].format == .recognition)
                    && (qs[j].movement == .warmup) == (qs[i].movement == .warmup)) { j += 1 }
            if j < qs.count { qs.swapAt(i, j) }
        }
        // Pass 2: never the same answer three times in a row.
        guard qs.count > 2 else { return qs }
        for i in 2..<qs.count {
            guard qs[i].expectedAnswer == qs[i - 1].expectedAnswer,
                  qs[i].expectedAnswer == qs[i - 2].expectedAnswer else { continue }
            var j = i + 1
            while j < qs.count,
                  !(qs[j].format == qs[i].format && qs[j].movement == qs[i].movement
                    && qs[j].expectedAnswer != qs[i].expectedAnswer
                    && qs[j].fact != qs[i - 1].fact) { j += 1 }
            if j < qs.count { qs.swapAt(i, j) }
        }
        return qs
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
                             rng: &rng, reviewTarget: 4, includeWarmup: false)
    }

    /// Ladder completion of a fact toward fluent, in [0, 1] (5 total rungs).
    func ladderProgress(_ id: FactID) -> Double {
        guard let s = fact(id)?.snapshot else { return 0 }
        if s.stage >= .fluency { return 1 }
        let done = s.stage == .recall ? 2 + min(s.recallCorrect, 3) : min(s.recognitionStreak, 2)
        return Double(done) / 5.0
    }

    /// Missing-factor mix, scaled to grasp: 1-in-3 of learning reps once a
    /// recall fact shows grasp (2 straight correct), 1-in-3 of fluent reviews,
    /// 1-in-2 once MASTERED — the better he knows it, the more the format
    /// mixes it up. Never ×0 facts. Static so a debug launch arg can force it.
    static var missingFactorDenominator: UInt64 = 3
    static let missingFactorMinFluent = 5

    /// Builds the quest in three phases so the input mode never thrashes:
    /// WARM-UP (typed review) → MEET (all multiple-choice for today's new facts)
    /// → TRAIN (typed: batch reps woven with cumulative review).
    private func assembleQuest(batch: [FactID], byID: [FactID: FactSnapshot],
                               snaps: [FactSnapshot], now: Date,
                               rng: inout SplitMix64, reviewTarget: Int = 25,
                               includeWarmup: Bool = true) -> [PlannedQuestion] {
        let fluencyTimes = snaps.flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        let threshold = FluencyThreshold.current(recentFluencyTimes: fluencyTimes)
        let fluentTotal = snaps.filter { $0.stage >= .fluency }.count

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
            // ×0/×1 are RULE facts — no answer cards (patronizing), straight to
            // keypad; one fast typed answer still tests out of recognition.
            let trivial = id.a <= 1
            if !trivial, stage == .recognition || !(s?.introduced ?? false) {
                // ONE card per fact per serving (never the same card twice in a
                // row) — the recognition streak also accrues from typed answers,
                // so the ladder loses nothing.
                let mcLeft = (s?.recognitionStreak ?? 0) >= 2 ? 0 : 1
                mcReps.append((0..<mcLeft).map { _ in question(id, format: .recognition, movement: .core) })
                typedReps.append((0..<3).map { _ in question(id, format: .recall, movement: .core) })
            } else if trivial, stage < .fluency {
                mcReps.append([])
                typedReps.append((0..<3).map { _ in question(id, format: .recall, movement: .core) })
            } else {
                mcReps.append([])
                let rc = s?.recallCorrect ?? 0
                let left = max(1, 3 - rc)
                // Grasp shown (2 straight correct): 1-in-3 remaining reps flip
                // to missing-factor — variety without new-fact load.
                typedReps.append((0..<left).map { _ in
                    let mf = rc >= 2 && id.a != 0 && rng.next() % 3 == 0
                    return question(id, format: .recall, movement: .core, missingFactor: mf)
                })
            }
        }

        // Cumulative review pool by priority — FLUENT-or-better facts only.
        // Sub-fluent facts are the batch's (or a future batch's) job: reviewing
        // them here could promote them mid-session and pop a second star, and
        // recognition-stage reviews would be cards ambushing a keypad phase.
        let batchSet = Set(batch)
        let reviewSnaps = snaps
            .filter { $0.introduced && $0.stage >= .fluency && !batchSet.contains($0.id)
                    && min($0.id.a, $0.id.b) > 1 }   // rule facts (×0/×1) never need review
            .sorted { Self.reviewWeight($0, now: now, threshold: threshold)
                    > Self.reviewWeight($1, now: now, threshold: threshold) }
            .prefix(reviewTarget)
        var reviews = reviewSnaps.map { s in
            if s.stage >= .fluency, s.id.a != 0, fluentTotal >= Self.missingFactorMinFluent,
               rng.next() % (s.stage == .mastered ? 2 : Self.missingFactorDenominator) == 0 {
                return question(s.id, format: .recall, movement: .review, missingFactor: true)
            }
            return question(s.id, format: s.stage == .mastered ? .fluency : s.stage, movement: .review)
        }.makeIterator()

        var queue: [PlannedQuestion] = []
        // WARM-UP: three easy typed reviews to get hands moving — long enough
        // that the blue phase reads as a round, not a flicker. Extensions skip
        // it ("warming up" mid-session is nonsense, and it kept the bar honest).
        if includeWarmup {
            for _ in 0..<3 {
                if let r = reviews.next() {
                    queue.append(PlannedQuestion(prompt: r.prompt, format: r.format,
                                                 movement: .warmup, options: r.options,
                                                 timed: r.timed, missingFactor: false))
                }
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
        // Top up with review so a quest is never a drive-by; the session's time
        // floor pulls backfill dynamically once this initial queue runs dry.
        while queue.count < 20, let r = reviews.next() { queue.append(r) }
        return Self.antiRepeat(queue)
    }

    private func currentThreshold() -> Double {
        let times = facts().flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        return FluencyThreshold.current(recentFluencyTimes: times)
    }

    /// Facts at Fluency or Mastered — gates the Speed Round (count-up + beat-your-best).
    func fluentPlusCount() -> Int { facts().filter { $0.stage >= .fluency }.count }

    /// The current fast-answer bar (boss crit-hits compare against this).
    func fluencyThresholdNow() -> Double { currentThreshold() }

    /// Session-start snapshot: the adventure's current world (boss-count based)
    /// plus GLOBAL fluency (worlds no longer own facts — the wrap shows global gains).
    func currentWorldStat() -> (index: Int, fluent: Int, total: Int) {
        (activeProfile().currentWorldIndex, fluentPlusCount(), FactUniverse.count)
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

    /// The world's boss challenge: a timed gauntlet over what he's actually been
    /// training (worlds no longer own facts) — his weakest introduced facts plus
    /// a shuffled spread of the rest. 10–16 questions; small pools repeat facts
    /// in fresh orientations.
    func buildBossSession(worldIndex: Int, now: Date = .now, seed: UInt64? = nil) -> [PlannedQuestion] {
        let snaps = facts().map(\.snapshot).filter { $0.introduced && $0.stage >= .recall }
        guard !snaps.isEmpty else { return [] }
        let threshold = currentThreshold()
        var rng = SplitMix64(seed: seed ?? UInt64(bitPattern: Int64(now.timeIntervalSince1970)))
        let weakest = snaps
            .sorted { Self.reviewWeight($0, now: now, threshold: threshold)
                    > Self.reviewWeight($1, now: now, threshold: threshold) }
            .prefix(8).map(\.id)
        var rest = snaps.map(\.id).filter { !weakest.contains($0) }
        rest.shuffle(using: &rng)
        var picks = Array(weakest) + rest.prefix(8)
        let target = min(max(picks.count, 10), 16)
        var i = 0
        while picks.count < target { picks.append(picks[i]); i += 1 }   // small pools repeat
        picks.shuffle(using: &rng)
        return picks.prefix(16).map { id in
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
                       practiced: Bool = true, starEarned: Bool = false,
                       fluentGained: Int = 0, now: Date = .now) -> Celebration? {
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
        rec.starEarned = starEarned
        rec.fluentGained = fluentGained
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
