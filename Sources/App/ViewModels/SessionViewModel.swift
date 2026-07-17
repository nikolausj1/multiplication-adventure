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
    private(set) var fluentGained = 0    // facts reaching Fluency this session
    private(set) var justMastered = false

    // Running session stats.
    private(set) var combo = 0            // consecutive correct (in-session streak)
    /// Correct answers in a row (any speed). Only a wrong answer resets it —
    /// getting them RIGHT is the reward, and it fires often. Speed is a separate,
    /// additive flourish (see wasFast), never a gate.
    private(set) var hotStreak = 0
    /// Set to the milestone number (4, 8, 12…) on the answer that reached it,
    /// else nil — drives the streak badge + sound for that one answer.
    private(set) var hotStreakReached: Int? = nil
    /// This answer was correct AND beat the adaptive speed bar — earns its own
    /// "Lightning fast!" callout on top of the streak (a bonus, not a gate).
    private(set) var wasFast = false
    private static let hotStreakStep = 4
    /// The header chip shows the fast-streak in a quest, the raw combo in a boss
    /// (which has its own crit soundscape and doesn't run the hot streak).
    var streakDisplay: Int { bossWorldIndex != nil ? combo : hotStreak }
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

    /// Session rails are ANSWER COUNTS, not time. A time floor made the bar
    /// creep on the wall clock — a kid answering questions saw no connection
    /// between effort and progress. Now a day IS its questions: the floor is
    /// sized to the planned queue (~30), so "finish your questions" and
    /// "fill the bar" are the same thing, and every answer moves it.
    /// Launch args (-questFloorAnswers n / -questCeilingAnswers n) override
    /// for demo/verify runs.
    private let floorAnswers = SessionViewModel.launchCount("-questFloorAnswers", fallback: 30)
    private let ceilingAnswersOverride = SessionViewModel.launchCount("-questCeilingAnswers", fallback: 0)
    /// Injectable clock (the -dumpQuestPlan simulator advances virtual time;
    /// per-question response timing still uses it).
    var now: () -> Date = { .now }
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
    /// Decided ONCE at build time: a day whose batch is mostly rule-table facts
    /// (×0/×1/×2) runs on the short floor. (Decided per-answer it oscillated
    /// as real facts chained in — the "first questions matter more" illusion.)
    private var shortFloorDay = false

    /// The Quest Meter averages the two finish gates: answers given and batch
    /// work done — `(answers/floor + work) / 2`. The answer term ticks on
    /// EVERY submit, so the bar always visibly moves; the work term adds the
    /// honest "learning left" weight and only both together reach 100%.
    /// (A min() of the gates was honest but flat through warmups and review
    /// stretches — exactly the "I answered and nothing happened" complaint.)
    /// Monotonic via high-water; snaps to 1.0 at completion.
    private(set) var questMeter: Double = 0
    private var meterHighWater: Double = 0
    /// Complete = answer floor met AND nothing left mid-ladder. Ceiling days
    /// complete via the mercy path in next() (star still earned).
    var questComplete: Bool {
        isQuest ? (totalAnswered >= effectiveFloorAnswers && batchDone) : stage == .finished
    }
    /// The daily floor, scaled: a rule-table day (batch mostly ×0/×1/×2)
    /// completes at half the count.
    private var effectiveFloorAnswers: Int {
        shortFloorDay ? min(floorAnswers, 15) : floorAnswers
    }
    /// Mercy cap: a brutal day still ends (star earned) at 2× the floor.
    private var ceilingAnswers: Int {
        ceilingAnswersOverride > 0 ? ceilingAnswersOverride : effectiveFloorAnswers * 2
    }
    private var batchDone: Bool {
        questBatch.allSatisfy { service.ladderProgress($0) >= 1 }
    }

    private func updateMeter() {
        guard isQuest else { return }
        let answersC = min(1.0, Double(totalAnswered) / Double(max(effectiveFloorAnswers, 1)))
        // Review-only days have no batch to finish — the bar is pure answer
        // count. Otherwise both gates weigh in equally.
        let blended = questBatch.isEmpty ? answersC : (answersC + min(1.0, questCharge)) / 2
        meterHighWater = max(meterHighWater, min(1.0, blended))
        questMeter = meterHighWater
    }

    private static func launchCount(_ key: String, fallback: Int) -> Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: key), i + 1 < args.count,
              let v = Int(args[i + 1]) else { return fallback }
        return v
    }

    /// Current quest phase (quest days with a batch only — review-only days, boss
    /// fights, and speed/test runs stay nil and the meter stays gold). The color
    /// ALWAYS matches the input on screen: green = cards, blue/gold = keypad.
    /// Extension rounds jolt backwards honestly ("bonus round") — only the fill
    /// is monotonic, never the color.
    private(set) var questPhase: QuestPhase?

    private func updatePhase() {
        // True/False is phase-neutral: it slots into the running phase without a
        // colour flip or jolt (its own TRUE/FALSE keys make the input obvious).
        guard isQuest, bossWorldIndex == nil, let q = current, !q.trueFalse else { return }
        let raw: QuestPhase = q.movement == .warmup ? .warmup
            : (q.format == .recognition ? .meet : .train)
        if let old = questPhase, raw != old { Feedback.fire(.phaseJolt) }
        questPhase = raw
    }

    /// Mastered count at session start (the wrap's Master Quest delta).
    private(set) var masteredBefore = 0

    /// Sockets per world (the profile's parent-adjustable goal), captured at
    /// session start for the header chip and star-earned overlay.
    private(set) var starsPerWorldGoal = WorldCatalog.starsPerWorld

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
        self.starsPerWorldGoal = service.starsPerWorldGoal()
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
            // Resume a same-day paused quest: answer counts, meter, and novelty
            // budget carry over. The queue rebuilds from current fact state —
            // leftovers-first frontier naturally re-picks the in-flight material.
            var carriedNew = 0
            if let paused = service.loadPausedQuest() {
                totalAnswered = paused.answered
                correctCount = paused.correct
                meterHighWater = paused.meter
                carriedNew = paused.newCount
            }
            let quest = service.buildDailyQuest()
            built = quest.queue
            questBatch = quest.batch
            shortFloorDay = !quest.batch.isEmpty
                && quest.batch.filter { min($0.a, $0.b) <= 2 }.count * 2 > quest.batch.count
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
        updatePhase()
        guard auto != .off else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.stage == .asking, let q = self.current else { return }
            self.answer(q.expectedAnswer)   // expectedAnswer handles MF + True/False
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
                                    countsTime: !q.missingFactor && !q.trueFalse,
                                    verifyOnly: q.trueFalse)
        touched.insert(q.fact)
        totalAnswered += 1
        if correct { correctCount += 1 }
        combo = correct ? combo + 1 : 0
        // Hot streak (quests only): any correct answer builds it, a miss resets
        // it — the reward is for getting them right. Being ALSO fast (adaptive
        // per-kid bar; untimed inverse questions don't qualify) earns a separate
        // speed flourish on the same answer.
        hotStreakReached = nil
        wasFast = false
        var rewardBonus = 0   // streak-milestone + speed XP folded into this answer
        if bossWorldIndex == nil {
            if correct {
                hotStreak += 1
                if hotStreak % Self.hotStreakStep == 0 { hotStreakReached = hotStreak }
                wasFast = !q.missingFactor && !q.trueFalse
                    && FluencyThreshold.isFast(rt, threshold: critThreshold)
                if let m = hotStreakReached { rewardBonus += (m / Self.hotStreakStep) * 10 }
                if wasFast { rewardBonus += 5 }
                service.applyRewardBonus(xp: rewardBonus, streakLength: hotStreak, speedBonus: wasFast)
            } else {
                hotStreak = 0
            }
        }
        responseTimes.append(rt)
        xpEarned += result.xp + rewardBonus

        lastCorrect = correct
        lastSelected = value
        lastCorrectAnswer = q.prompt.answer
        lastXP = result.xp + rewardBonus
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
            // The reward that used to fire on a silent fact-graduation now lands
            // on a hot streak — something the kid can see himself earning.
            if hotStreakReached != nil { Feedback.fire(.milestone) }
        }
        if result.becameFluent {
            fluentGained += 1
            // (No celebration here anymore — a fluent fact is invisible to the
            //  kid; the streak is the moment he can attribute to his own play.)
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
                : (justMastered || hotStreakReached != nil) ? 1.6 : 0.9   // let the moment land
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
            if totalAnswered >= ceilingAnswers { completeQuest(); return }   // mercy: star still earned
            if questComplete { completeQuest(); return }   // floor + in-flight work done
            if index >= queue.count {
                // Miss recovery for in-flight facts first; then (floor unmet)
                // chain the next frontier batch; then pure review rounds.
                var more = service.questExtension(batch: questBatch)
                if totalAnswered >= effectiveFloorAnswers {
                    // Overtime (floor met, batch unfinished): serve ONLY reps
                    // that can still move the work gate — core reps of facts
                    // whose ladder isn't maxed for today. Interleaved reviews
                    // and re-serves of already-complete facts don't move the
                    // bar, and a bar that sits still while the kid answers is
                    // the exact complaint this design fixes. When nothing
                    // gainable remains, the quest completes right here.
                    more = more.filter {
                        $0.movement == .core && service.ladderProgress($0.fact) < 1
                    }
                }
                if more.isEmpty, totalAnswered < effectiveFloorAnswers {
                    // A chained batch must FIT the remaining floor: a late
                    // chain overruns the day and dilutes the work gate below
                    // the bar's high-water, so the bar sits flat while the new
                    // facts catch up (the kid-visible stall this design exists
                    // to kill). Chain sizes vary (rule chains are short), so
                    // build the chain and accept it only if it fits; otherwise
                    // reviews walk the bar to the floor.
                    let headroom = effectiveFloorAnswers - totalAnswered
                    // Hot streak: budget gone but he's ≥90% accurate on a real
                    // sample — grant one +4 bonus so the frontier keeps moving.
                    if !budgetBonusGranted, newIntroduced >= newFactBudget,
                       totalAnswered >= 10, accuracy >= 0.9 {
                        budgetBonusGranted = true
                    }
                    var chained = service.chainBatch(exclude: Set(questBatch),
                                                     maxFresh: effectiveBudget - newIntroduced)
                    if chained.queue.count > headroom { chained = (queue: [], batch: []) }
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
    /// adaptive ladder actually saves the time it promises. In OVERTIME (floor
    /// met, batch unfinished) the skip widens to anything that can't move the
    /// work gate — reviews and maxed-for-today reps included — so every
    /// remaining answer visibly moves the bar and the day ends the moment
    /// nothing gainable is left.
    private func skipStaleReps() {
        let overtime = isQuest && totalAnswered >= effectiveFloorAnswers
        while index < queue.count {
            let q = queue[index]
            if overtime {
                guard q.movement != .core || service.ladderProgress(q.fact) >= 1
                else { break }
            } else {
                guard q.movement == .core, q.format != .fluency,
                      service.ladderProgress(q.fact) >= 1 else { break }
            }
            index += 1
        }
    }

    /// Quest complete: award the day's star (nil socket = boss pending, no star
    /// to give until the boss falls). The slam overlay is the finale — the bar
    /// is full and gold — and the wrap follows its dismissal.
    private func completeQuest() {
        if !questEndPending {
            // The finale contract: the bar is FULL when the star slams in —
            // even on mercy-ceiling days where the ladder work isn't 100%.
            meterHighWater = 1; questMeter = 1
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

    /// X on a quest = PAUSE for the day, not quit: answer counts, bar, and
    /// budget are saved; tapping the world resumes. (Learning was already
    /// recorded per answer either way.) Boss/speed/test runs end normally.
    func stop() {
        guard stage != .finished else { return }
        if isQuest, !questEndPending, auto == .off {
            service.savePausedQuest(answered: totalAnswered, correct: correctCount,
                                    meter: meterHighWater, newCount: newIntroduced)
            didPause = true
            stage = .finished   // the view sees didPause and dismisses (no wrap)
            return
        }
        finish()
    }

    private func finish() {
        stage = .finished
        if auto == .wrap { pendingStarEarned = nil }   // demo autoplay: don't trap the wrap
        // Strict flame: dev jumps never count; quests count when the day's star
        // landed or real work was put in; boss and speed runs always count.
        let practiced = !isTest && (starEarnedThisSession || bossWorldIndex != nil
                                    || isSpeed || totalAnswered >= 20)
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
