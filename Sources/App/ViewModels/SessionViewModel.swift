import SwiftUI
import SwiftData

/// The quest's three rounds. The Quest Meter wears a different color per phase
/// (blue → purple → gold, the rarity ladder) and jolts at each transition.
enum QuestPhase: Int, Comparable {
    case warmup, meet, train
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Drives one practice session: serves questions, records answers, re-queues wrong
/// answers within the session, and surfaces celebrations. The child never chooses
/// anything (§3) — this object always knows what comes next.
@MainActor
@Observable
final class SessionViewModel {
    enum Stage { case asking, feedback, finished }

    private(set) var queue: [PlannedQuestion]
    private(set) var index = 0
    private(set) var stage: Stage = .asking

    // Per-answer feedback state (neutral-soft reveal).
    private(set) var lastCorrect = false
    private(set) var lastCorrectAnswer = 0
    private(set) var lastSelected: Int?
    private(set) var lastXP = 0
    private(set) var justFluent = false
    private(set) var fluentGained = 0    // facts reaching Fluency this session
    private(set) var justMastered = false

    // Running session stats.
    private(set) var combo = 0            // consecutive correct (in-session streak)
    private(set) var correctCount = 0
    private(set) var totalAnswered = 0
    private(set) var xpEarned = 0
    private(set) var responseTimes: [Double] = []
    private var touched = Set<FactID>()

    var pendingCelebration: Celebration?
    /// 0-based index of a just-earned world star; drives the full-screen slam overlay.
    var pendingStarEarned: Int?
    private(set) var endCelebration: Celebration?

    /// Debug autoplay (launch-arg gated) for screenshot verification.
    enum AutoMode { case off, feedback, wrap }

    private let service: LearningService
    private let timed: Bool
    private let isSpeed: Bool
    private let isTest: Bool
    private let auto: AutoMode
    private var questionStart = Date.now
    private let originalCount: Int
    private var feedbackGen = 0

    /// Current-world fluency at session start, so the wrap can show today's gains.
    let worldStatBefore: (index: Int, fluent: Int, total: Int)
    /// What the header star chip shows — current world's sockets, frozen at
    /// session start so the new star appears NOWHERE before the slam ceremony.
    private(set) var shownStars = 0
    /// The star chip only makes sense in a regular quest session.
    let showsWorldRing: Bool

    /// Set for a world-boss challenge run; the wrap uses `bossPassed` for its verdict.
    let bossWorldIndex: Int?
    private(set) var bossPassed = false
    /// Faster-than-threshold boss answers land CRITICAL hits (bigger flinch + callout).
    private(set) var critCount = 0
    private(set) var lastHitCritical = false
    private let critThreshold: Double
    /// Correct answers needed to visually defeat the guardian (the pass bar).
    var bossHPTotal: Int {
        max(1, Int(ceil(Double(originalCount) * LearningService.bossPassAccuracy)))
    }

    /// Daily Quest state: the facts being drilled this session (frontier batches
    /// chain as earlier ones finish). The star is a SESSION trophy — awarded at
    /// completion (time floor + in-flight work done), decoupled from fluency.
    private(set) var questBatch: [FactID] = []
    private(set) var starEarnedThisSession = false
    /// 0-based socket of the star awarded at completion; slams before the wrap.
    private var earnedStarIndex: Int?
    private var questEndPending = false   // slam showing; finish() on its dismissal
    /// Ladder completion of today's batch facts in [0, 1] (the meter's work part).
    private(set) var questCharge: Double = 0
    let isQuest: Bool

    /// Session rails are TIME, not question counts — "a good day's practice" is
    /// ~12 minutes whether he's sprinting ×10s in July or grinding ×8s in August.
    /// Launch args (-questFloorSeconds n / -questCeilingSeconds n) override for
    /// demo/verify runs.
    private let floorSeconds = SessionViewModel.launchSeconds("-questFloorSeconds", fallback: 12 * 60)
    private let ceilingSeconds = SessionViewModel.launchSeconds("-questCeilingSeconds", fallback: 20 * 60)
    /// Injectable clock (the -dumpQuestPlan simulator advances virtual time).
    var now: () -> Date = { .now }
    /// The clock counts ACTIVE screen time only — a snack break (backgrounded
    /// app or paused session) never fills the bar by itself.
    private var accumulatedActive: TimeInterval = 0
    private var activeSince: Date?
    var elapsed: TimeInterval {
        accumulatedActive + (activeSince.map { now().timeIntervalSince($0) } ?? 0)
    }
    func clockRun() { if activeSince == nil { activeSince = now() } }
    func clockPause() {
        if let s = activeSince { accumulatedActive += now().timeIntervalSince(s) }
        activeSince = nil
    }
    /// X pressed mid-quest: paused for the day (the view dismisses, no wrap).
    private(set) var didPause = false
    /// Review serves per fact this session (cap 2 — a small pool must not cycle).
    private var reviewCounts: [FactID: Int] = [:]
    /// Novelty budget: at most this many BRAND-NEW facts introduced per session
    /// (ten names remembered beats forty-four forgotten). Leftover sub-fluent
    /// facts from earlier days don't count; once spent, the clock fills with
    /// reps and reviews instead of introductions.
    private let newFactBudget = 12
    private var newIntroduced = 0
    /// Hot-streak bonus: budget spent at ≥90% accuracy unlocks one +4 extension
    /// (a cruising day shouldn't stall on reviews when he's clearly absorbing).
    private var budgetBonusGranted = false
    private var effectiveBudget: Int { newFactBudget + (budgetBonusGranted ? 4 : 0) }
    /// Answers on rule-table facts (×0/×1/×2) this session — while they dominate,
    /// the habit floor shortens (day one shouldn't stretch on zeros).
    private var trivialAnswered = 0

    /// The Quest Meter: EVERY answer moves it — the session clock is the main
    /// component (60%), today's ladder work the rest (40%). Monotonic via
    /// high-water mark; hits 1.0 exactly at quest completion.
    private(set) var questMeter: Double = 0
    private var meterHighWater: Double = 0
    /// Complete = clock satisfied AND nothing left mid-ladder. Ceiling days
    /// complete via the mercy path in next() (star still earned).
    var questComplete: Bool {
        isQuest ? (elapsed >= effectiveFloorSeconds && batchDone) : stage == .finished
    }
    /// The habit floor, scaled: while >50% of answers come from the rule tables
    /// (×0/×1/×2), the quest may complete at 6 minutes instead of the full floor.
    private var effectiveFloorSeconds: TimeInterval {
        guard totalAnswered >= 6, trivialAnswered * 2 > totalAnswered else { return floorSeconds }
        return min(floorSeconds, 6 * 60)
    }
    private var batchDone: Bool {
        questBatch.allSatisfy { service.ladderProgress($0) >= 1 }
    }

    private func updateMeter() {
        guard isQuest else { return }
        let workC = questBatch.isEmpty ? 1.0 : questCharge
        let floorC = min(1.0, elapsed / max(effectiveFloorSeconds, 1))
        meterHighWater = max(meterHighWater, 0.4 * workC + 0.6 * floorC)
        questMeter = meterHighWater
    }

    private static func launchSeconds(_ key: String, fallback: TimeInterval) -> TimeInterval {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: key), i + 1 < args.count,
              let v = TimeInterval(args[i + 1]) else { return fallback }
        return v
    }

    /// Current quest phase (quest days with a batch only — review-only days, boss
    /// fights, and speed/test runs stay nil and the meter stays gold). The color
    /// ALWAYS matches the input on screen: green = cards, blue/gold = keypad.
    /// Extension rounds jolt backwards honestly ("bonus round") — only the fill
    /// is monotonic, never the color.
    private(set) var questPhase: QuestPhase?

    private func updatePhase() {
        guard isQuest, bossWorldIndex == nil, let q = current else { return }
        let raw: QuestPhase = q.movement == .warmup ? .warmup
            : (q.format == .recognition ? .meet : .train)
        if let old = questPhase, raw != old { Feedback.fire(.phaseJolt) }
        questPhase = raw
    }

    /// Mastered count at session start (the wrap's Master Quest delta).
    private(set) var masteredBefore = 0

    init(service: LearningService, speedRound: Bool = false, boss: Bool = false,
         auto: AutoMode = .off, worldIndex: Int = 0, testFormat: MasteryStage? = nil) {
        self.service = service
        // Speed Round, boss challenges, and dev fluency always show the timer;
        // regular practice only when the profile opts into "speed" timing.
        self.timed = speedRound || boss || testFormat == .fluency
            || service.activeProfile().timingMode == .speed
        self.isSpeed = speedRound
        self.isTest = testFormat != nil
        self.bossWorldIndex = boss ? worldIndex : nil
        self.critThreshold = service.fluencyThresholdNow()
        self.auto = auto
        self.worldStatBefore = service.currentWorldStat()
        self.shownStars = service.starsInCurrentWorld()
        self.isQuest = !speedRound && !boss && testFormat == nil
        self.showsWorldRing = isQuest
        let built: [PlannedQuestion]
        if boss {
            built = service.buildBossSession(worldIndex: worldIndex)
        } else if let testFormat {
            built = service.buildTestSession(worldIndex: worldIndex, format: testFormat)
        } else if speedRound {
            built = service.buildSpeedSession()
        } else {
            // Resume a same-day paused quest: clock, meter, and novelty budget
            // carry over. The queue rebuilds from current fact state — leftovers-
            // first frontier naturally re-picks the same in-flight material.
            var carriedNew = 0
            if let paused = service.loadPausedQuest() {
                accumulatedActive = paused.elapsed
                meterHighWater = paused.meter
                carriedNew = paused.newCount
            }
            let quest = service.buildDailyQuest()
            built = quest.queue
            questBatch = quest.batch
            questCharge = Self.charge(of: quest.batch, service: service)
            newIntroduced = carriedNew + quest.batch.filter { !service.isIntroduced($0) }.count
        }
        self.queue = built
        self.originalCount = built.count
        for q in built where q.movement != .core { reviewCounts[q.fact, default: 0] += 1 }
        self.masteredBefore = service.activeProfile().masteredCount
        questionStart = .now
        if built.isEmpty { stage = .finished }   // e.g. Speed Round with no fluent facts yet
        updateMeter()
        updatePhase()   // meter opens already wearing round 1's color (no jolt)
    }

    var current: PlannedQuestion? { index < queue.count ? queue[index] : nil }

    private static func charge(of batch: [FactID], service: LearningService) -> Double {
        guard !batch.isEmpty else { return 0 }
        return batch.map { service.ladderProgress($0) }.reduce(0, +) / Double(batch.count)
    }

    /// Progress: the quest meter on quest days; queue progress otherwise.
    var progress: Double {
        if isQuest { return questMeter }
        return originalCount == 0 ? 1 : min(1, Double(distinctServed) / Double(originalCount))
    }
    private var distinctServed: Int { min(index, originalCount) }

    var movementLabel: String {
        switch current?.movement {
        case .warmup: return "Warm-up"
        case .core:   return "Practice"
        case .review: return "Review"
        case .none:   return ""
        }
    }

    func beginQuestion() {
        questionStart = .now
        clockRun()
        updatePhase()
        guard auto != .off else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.stage == .asking, let q = self.current else { return }
            self.answer(q.prompt.answer)
            if self.auto == .wrap {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.next() }
            }
        }
    }

    func answer(_ value: Int, simulatedRT: Double? = nil) {
        guard stage == .asking, let q = current else { return }
        let rt = simulatedRT ?? Date.now.timeIntervalSince(questionStart)
        let correct = value == q.expectedAnswer

        // Inverse-form answers are naturally slower; keep them out of the speed baseline.
        let result = service.record(prompt: q.prompt, format: q.format,
                                    correct: correct, responseTime: rt,
                                    countsTime: !q.missingFactor)
        touched.insert(q.fact)
        totalAnswered += 1
        if isQuest, min(q.fact.a, q.fact.b) <= 2 { trivialAnswered += 1 }
        if correct { correctCount += 1 }
        combo = correct ? combo + 1 : 0
        responseTimes.append(rt)
        xpEarned += result.xp

        lastCorrect = correct
        lastSelected = value
        lastCorrectAnswer = q.prompt.answer
        lastXP = result.xp
        justFluent = result.becameFluent
        justMastered = result.becameMastered
        if bossWorldIndex != nil {
            // Boss fights have their own soundscape: hits instead of coins.
            if correct {
                lastHitCritical = FluencyThreshold.isFast(rt, threshold: critThreshold)
                if lastHitCritical { critCount += 1 }
                Feedback.fire(.bossHit)
                if lastHitCritical { Feedback.fire(.correct, combo: 8) }  // bright zing on top
                if correctCount == bossHPTotal { Feedback.fire(.bossDefeat) }
            } else {
                lastHitCritical = false
                Feedback.fire(.wrong)
            }
        } else {
            Feedback.fire(correct ? .correct : .wrong, combo: combo)
        }
        // Stars are session trophies now (awarded at completion) — a fact going
        // fluent is still its own magic moment.
        if result.becameFluent {
            fluentGained += 1
            Feedback.fire(.milestone)
            // Adaptive budget: a fact cleared in ≤3 flawless answers was already
            // known — refund its novelty slot so the frontier keeps reaching
            // until it finds material that actually makes him work.
            if let s = service.fact(q.fact)?.snapshot,
               s.totalAttempts <= 3, s.totalCorrect == s.totalAttempts {
                newIntroduced = max(0, newIntroduced - 1)
            }
        }
        if isQuest { questCharge = Self.charge(of: questBatch, service: service) }
        updateMeter()
        if let c = result.celebration {
            pendingCelebration = c
            Feedback.fire(c.tier >= .t3 ? .milestone : .levelUp)
        }

        // A wrong answer re-queues the fact a few slots later (§4.4) — but never
        // across an input-mode boundary: a missed card retries inside the card
        // round, and a keypad retry never splits a card block. The bar's color
        // must always match the input on screen. Boss fights are one shot per
        // question — no retries, or victory would be grindable.
        if !correct, bossWorldIndex == nil {
            var at = min(index + 4, queue.count)
            var retry = q
            if q.format == .recognition {
                var boundary = index + 1
                while boundary < queue.count, queue[boundary].format == .recognition {
                    boundary += 1
                }
                at = min(at, boundary)
                if at <= index + 1 {
                    // No room left in the card block: retry as a typed question
                    // a beat later (the reveal just showed him the answer) —
                    // never the same card twice in a row, never a card ambushing
                    // a keypad phase.
                    retry = PlannedQuestion(prompt: q.prompt, format: .recall,
                                            movement: q.movement, options: nil,
                                            timed: false)
                    at = min(index + 2, queue.count)
                }
            } else {
                at = max(at, min(index + 2, queue.count))
                while at > 0, at < queue.count,
                      queue[at].format == .recognition,
                      queue[at - 1].format == .recognition {
                    at += 1
                }
            }
            // Nothing to space against (missed the very last question): skip the
            // in-session retry — the fact stays sub-fluent, so extensions or
            // tomorrow's batch re-serve it anyway. Never twice in a row.
            if at >= index + 2 { queue.insert(retry, at: at) }
        }
        stage = .feedback
        feedbackGen += 1

        // Correct answers keep the flow: advance automatically after a beat.
        // Misses wait for an explicit Continue so the reveal actually lands.
        if correct, auto == .off {
            let gen = feedbackGen
            // Killing blow gets a long beat so the defeat animation plays out.
            let delay = (bossWorldIndex != nil && correctCount >= bossHPTotal) ? 2.2
                : (justMastered || justFluent) ? 1.6 : 0.9   // let the ring moment land
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.stage == .feedback, self.feedbackGen == gen,
                      self.pendingCelebration == nil,
                      self.pendingStarEarned == nil else { return }   // overlay up → wait for its dismissal
                self.next()
            }
        }
    }

    /// Celebration overlay dismissed; if it was holding up a correct-answer
    /// auto-advance, move on now.
    func celebrationDismissed() {
        pendingCelebration = nil
        if stage == .feedback, lastCorrect, auto == .off, pendingStarEarned == nil { next() }
    }

    /// Star-earned overlay dismissed. The slam is the quest's finale, so this
    /// normally rolls straight into the wrap.
    func starEarnedDismissed() {
        pendingStarEarned = nil
        if questEndPending { finish(); return }
        if stage == .feedback, lastCorrect, auto == .off, pendingCelebration == nil { next() }
    }

    /// Debug (launch-arg): show the star-earned overlay without earning one.
    func debugShowStar(_ index: Int) { pendingStarEarned = index }

    /// Advance after the neutral-soft reveal. A quest ends when the clock is
    /// satisfied AND nothing is left mid-ladder; until then it keeps chaining
    /// real work (extensions → next frontier batch → review rounds).
    func next() {
        guard stage == .feedback else { return }
        let servedFact = current?.fact
        index += 1
        skipStaleReps()
        dedupeAdjacent(servedFact)
        lastSelected = nil

        // Boss dies the moment his HP empties — instant victory, no leftover
        // questions against a corpse.
        if bossWorldIndex != nil, correctCount >= bossHPTotal {
            finish(); return
        }
        if isQuest {
            if elapsed >= ceilingSeconds { completeQuest(); return }   // mercy: star still earned
            if questComplete { completeQuest(); return }   // clock + in-flight work done
            if index >= queue.count {
                // Miss recovery for in-flight facts first; then (clock unmet)
                // chain the next frontier batch; then pure review rounds.
                var more = service.questExtension(batch: questBatch)
                if more.isEmpty, elapsed < effectiveFloorSeconds {
                    // Hot streak: budget gone but he's ≥90% accurate on a real
                    // sample — grant one +4 bonus so the frontier keeps moving.
                    if !budgetBonusGranted, newIntroduced >= newFactBudget,
                       totalAnswered >= 10, accuracy >= 0.9 {
                        budgetBonusGranted = true
                    }
                    let chained = service.chainBatch(exclude: Set(questBatch),
                                                     maxFresh: effectiveBudget - newIntroduced)
                    if chained.batch.isEmpty {
                        let capped = Set(reviewCounts.filter { $0.value >= 2 }.keys)
                        more = service.reviewRound(reviewExclude: capped)
                        for q in more where q.movement == .review {
                            reviewCounts[q.fact, default: 0] += 1
                        }
                    } else {
                        newIntroduced += chained.batch.filter { !service.isIntroduced($0) }.count
                        questBatch += chained.batch
                        questCharge = Self.charge(of: questBatch, service: service)
                        more = chained.queue
                    }
                }
                if more.isEmpty { completeQuest() } else {   // floor met or truly dry
                    queue.append(contentsOf: more)
                    dedupeAdjacent(servedFact)   // guard the seam too
                    stage = .asking; beginQuestion()
                }
                return
            }
        } else if index >= queue.count {
            finish(); return
        }
        stage = .asking; beginQuestion()
    }

    /// Serve-time net: never the same fact twice in a row. Planners avoid it,
    /// but dynamic inserts, chained batches, and single-fact tails can't always.
    /// Swaps stay format- and warmup-compatible so phase blocks survive.
    private func dedupeAdjacent(_ last: FactID?) {
        guard let last, index < queue.count, queue[index].fact == last else { return }
        var j = index + 1
        while j < queue.count,
              !(queue[j].fact != last
                && (queue[j].format == .recognition) == (queue[index].format == .recognition)
                && (queue[j].movement == .warmup) == (queue[index].movement == .warmup)) { j += 1 }
        if j < queue.count {
            queue.swapAt(index, j)
        } else if index + 1 < queue.count, queue.last?.fact != last {
            // No swap candidate: defer the duplicate to the end of the queue.
            queue.append(queue.remove(at: index))
        }
    }

    /// Testing out makes pre-planned ladder reps stale: once a fact reaches
    /// fluent, its remaining card/recall reps teach nothing — skip them so the
    /// adaptive ladder actually saves the time it promises.
    private func skipStaleReps() {
        while index < queue.count {
            let q = queue[index]
            guard q.movement == .core, q.format != .fluency,
                  service.ladderProgress(q.fact) >= 1 else { break }
            index += 1
        }
    }

    /// Quest complete: award the day's star (nil socket = boss pending, no star
    /// to give until the boss falls). The slam overlay is the finale — the bar
    /// is full and gold — and the wrap follows its dismissal.
    private func completeQuest() {
        if !questEndPending {
            service.clearPausedQuest()   // completed — nothing left to resume
            earnedStarIndex = service.awardQuestStar()
            starEarnedThisSession = earnedStarIndex != nil
            shownStars = service.starsInCurrentWorld()
        }
        if let star = earnedStarIndex, !questEndPending, auto != .wrap {
            questEndPending = true
            pendingStarEarned = star
        } else {
            finish()
        }
    }

    /// X on a quest = PAUSE for the day, not quit: clock, bar, and budget are
    /// saved; tapping the world resumes. (Learning was already recorded per
    /// answer either way.) Boss/speed/test runs end normally.
    func stop() {
        guard stage != .finished else { return }
        if isQuest, !questEndPending, auto == .off {
            clockPause()
            service.savePausedQuest(elapsed: elapsed, meter: meterHighWater,
                                    newCount: newIntroduced)
            didPause = true
            stage = .finished   // the view sees didPause and dismisses (no wrap)
            return
        }
        finish()
    }

    private func finish() {
        stage = .finished
        clockPause()
        if auto == .wrap { pendingStarEarned = nil }   // demo autoplay: don't trap the wrap
        // Strict flame: dev jumps never count; quests count when the day's star
        // landed or real time was put in; boss and speed runs always count.
        let practiced = !isTest && (starEarnedThisSession || bossWorldIndex != nil
                                    || isSpeed || elapsed >= 480)
        endCelebration = service.finishSession(
            questionCount: totalAnswered, correctCount: correctCount, xpEarned: xpEarned,
            responseTimes: responseTimes, factsTouched: touched.count,
            speed: isSpeed, bossWorld: bossWorldIndex, practiced: practiced,
            starEarned: starEarnedThisSession, fluentGained: fluentGained)
        if let bossWorldIndex {
            bossPassed = service.activeProfile().clearedWorlds.contains(bossWorldIndex)
            Feedback.fire(bossPassed ? .levelUp : .wrong)
        }
    }

    var accuracy: Double { totalAnswered == 0 ? 0 : Double(correctCount) / Double(totalAnswered) }
    var showTimer: Bool { timed }
}
