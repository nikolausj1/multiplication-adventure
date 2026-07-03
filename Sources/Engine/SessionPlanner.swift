import Foundation

public enum SessionMovement: Int, Sendable, Equatable {
    case warmup, core, review
}

/// One planned question: which fact, in which orientation, in which format.
public struct PlannedQuestion: Sendable, Equatable {
    public let prompt: OrientedPrompt
    public let format: MasteryStage      // .recognition → MC; .recall/.fluency → open
    public let movement: SessionMovement
    public let options: [Int]?           // populated for recognition
    public let timed: Bool               // fluency-format questions are timed

    public var fact: FactID { prompt.fact }
}

public struct SessionConfig: Sendable {
    public var targetQuestions: Int
    public var warmupCount: Int
    public var newFactsPerSession: Int
    public var targetInFlight: Int
    public init(targetQuestions: Int = 24, warmupCount: Int = 4,
                newFactsPerSession: Int = 4, targetInFlight: Int = 10) {
        self.targetQuestions = targetQuestions
        self.warmupCount = warmupCount
        self.newFactsPerSession = newFactsPerSession
        self.targetInFlight = targetInFlight
    }
}

/// Builds a session: warm-up → core → review, interleaved (§4.6, §6). The app
/// always knows what comes next; the child never chooses (§3). Pure and seeded.
public enum SessionPlanner {

    public static func plan(
        snapshots: [FactSnapshot],
        now: Date,
        seed: UInt64,
        config: SessionConfig = SessionConfig()
    ) -> [PlannedQuestion] {
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        let fluencyTimes = snapshots.flatMap { $0.stage >= .fluency ? $0.recentTimes : [] }
        let threshold = FluencyThreshold.current(recentFluencyTimes: fluencyTimes)

        func priority(_ f: FactSnapshot) -> Double {
            PriorityCalculator.priority(of: f, now: now, fluencyThreshold: threshold)
        }

        let introduced = snapshots.filter { $0.introduced }
        let mastered = introduced.filter { $0.stage == .mastered }

        // 1. New facts (gated introduction, §5) — scoped to the current world so the
        //    next world's facts never appear until it unlocks. Review stays cumulative.
        let currentWorld = WorldProgress.currentIndex(snapshots: snapshots)
        let allowedMaxSlot = WorldCatalog.maxSlot(forWorld: currentWorld)
        let newFacts = chooseNewFacts(snapshots: snapshots, config: config,
                                      allowedMaxSlot: allowedMaxSlot)
        let newIDs = Set(newFacts.map { $0.id })

        var used = Set<FactID>()
        var warmup: [FactID] = []
        var core: [FactID] = []
        var review: [FactID] = []

        // 2. Warm-up: already-mastered facts for confidence. Cold start (none mastered)
        //    falls back to the strongest introduced facts, or simply yields nothing.
        let warmupSource = mastered.isEmpty
            ? introduced.sorted { $0.box > $1.box }
            : mastered.sorted { ($0.dueDate) < ($1.dueDate) }
        for f in warmupSource where warmup.count < config.warmupCount {
            if used.insert(f.id).inserted { warmup.append(f.id) }
        }

        // 3. Core: new facts first (recognition), then learning-stage facts by priority.
        for f in newFacts where !used.contains(f.id) {
            if used.insert(f.id).inserted { core.append(f.id) }
        }
        let learning = introduced
            .filter { $0.stage == .recognition || $0.stage == .recall }
            .sorted { priority($0) > priority($1) }
        let coreTarget = max(0, (config.targetQuestions - warmup.count) * 6 / 10)
        for f in learning where core.count < coreTarget {
            if used.insert(f.id).inserted { core.append(f.id) }
        }

        // 4. Review: spaced-due facts + historically difficult, including fluency bursts.
        let due = introduced
            .filter { !used.contains($0.id) && $0.isDue(asOf: now) && $0.box >= 1 }
            .sorted { priority($0) > priority($1) }
        for f in due where (warmup.count + core.count + review.count) < config.targetQuestions {
            if used.insert(f.id).inserted { review.append(f.id) }
        }
        // Top up from anything introduced if the day is thin on due facts.
        if (warmup.count + core.count + review.count) < config.targetQuestions {
            let filler = introduced
                .filter { !used.contains($0.id) }
                .sorted { priority($0) > priority($1) }
            for f in filler where (warmup.count + core.count + review.count) < config.targetQuestions {
                if used.insert(f.id).inserted { review.append(f.id) }
            }
        }

        // Assemble questions. Warm-up keeps its place at the front; core+review are
        // interleaved so the same table never (where avoidable) appears back to back.
        var rng = SplitMix64(seed: seed)
        func makeQuestion(_ id: FactID, movement: SessionMovement) -> PlannedQuestion {
            let snap = byID[id] ?? FactSnapshot(id: id)
            // Warm-up presents mastered facts in their fluent, open, timed format.
            let format: MasteryStage = movement == .warmup
                ? (snap.stage == .mastered ? .fluency : snap.stage)
                : (newIDs.contains(id) ? .recognition : snap.stage)
            let swapped = (rng.next() & 1) == 1
            let prompt = OrientedPrompt(fact: id, swapped: swapped)
            let options = format == .recognition
                ? DistractorGenerator.options(for: prompt, seed: rng.next())
                : nil
            return PlannedQuestion(prompt: prompt, format: format, movement: movement,
                                   options: options, timed: format == .fluency)
        }

        let warmupQs = warmup.map { makeQuestion($0, movement: .warmup) }
        let coreQs = core.map { makeQuestion($0, movement: .core) }
        let reviewQs = review.map { makeQuestion($0, movement: .review) }
        let interleaved = interleaveByTable(coreQs + reviewQs)

        // Brand-new facts get a second rep at the session's end: two correct
        // multiple-choice answers promote them to Recall on day one, so the first
        // unlock arrives fast while the recall reps stay spaced across sessions.
        let secondReps = newFacts.map { makeQuestion($0.id, movement: .review) }

        return warmupQs + interleaved + secondReps
    }

    /// Gated new-fact introduction (§5): keep a bounded number of facts in flight,
    /// open the next table only once earlier ones are fully introduced and ~80%
    /// fluent, but always keep a trickle so momentum never stalls.
    static func chooseNewFacts(snapshots: [FactSnapshot], config: SessionConfig,
                               allowedMaxSlot: Int = Int.max) -> [FactSnapshot] {
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        let introduced = snapshots.filter { $0.introduced }
        let inFlight = introduced.filter { $0.stage < .mastered }.count
        guard inFlight < config.targetInFlight else { return [] }

        let fluentPlus = introduced.filter { $0.stage >= .fluency }.count
        let fluentFraction = introduced.isEmpty ? 1.0 : Double(fluentPlus) / Double(introduced.count)
        let gateOpen = introduced.isEmpty || fluentFraction >= 0.8 || inFlight < 4
        guard gateOpen else { return [] }

        // Walk slots in curriculum order; only open a slot once all earlier slots are
        // fully introduced.
        let slots = Curriculum.factsBySlot()
        var picks: [FactSnapshot] = []
        let cap = min(config.newFactsPerSession, config.targetInFlight - inFlight)
        for (slotIndex, slot) in slots.enumerated() {
            if slotIndex > allowedMaxSlot { break }   // don't introduce beyond the current world
            let notIntroduced = slot.filter { !(byID[$0]?.introduced ?? false) }
            for fact in notIntroduced where picks.count < cap {
                if let snap = byID[fact] { picks.append(snap) }
            }
            // Stop once the per-session cap is reached; otherwise finish this slot and
            // continue to the next frontier slot. Earlier slots are always filled first,
            // so a table is completed before the next one opens.
            if picks.count >= cap { break }
        }
        return picks
    }

    /// Greedy interleave so consecutive questions avoid sharing the larger factor.
    static func interleaveByTable(_ questions: [PlannedQuestion]) -> [PlannedQuestion] {
        var remaining = questions
        var result: [PlannedQuestion] = []
        result.reserveCapacity(questions.count)
        while !remaining.isEmpty {
            let lastTable = result.last?.fact.b
            let idx = remaining.firstIndex(where: { $0.fact.b != lastTable }) ?? 0
            result.append(remaining.remove(at: idx))
        }
        return result
    }
}
