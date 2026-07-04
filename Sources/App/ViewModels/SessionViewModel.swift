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
    /// Live ring: fluent count of the session's world, updated after every answer.
    private(set) var worldFluent = 0
    /// What the header star chip shows — frozen at session start so the star
    /// appears NOWHERE before the slam ceremony (updated at quest completion).
    private(set) var shownWorldFluent = 0
    var worldTotal: Int { worldStatBefore.total }
    /// The ring only makes sense in a regular progression session.
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

    /// Star Quest state: today's batch of facts being drilled to fluent. Empty for
    /// boss/speed/test runs and boss-pending review days.
    private(set) var questBatch: [FactID] = []
    private(set) var starEarnedThisSession = false
    /// 0-based index of the star earned this session; slams at quest completion.
    private var earnedStarIndex: Int?
    private var questEndPending = false   // slam showing; finish() on its dismissal
    /// Ladder charge of today's star in [0, 1] — drives the top progress bar.
    private(set) var questCharge: Double = 0
    var isQuest: Bool { !questBatch.isEmpty }

    /// Session rails are TIME, not question counts — "a good day's practice" is
    /// ~12 minutes whether he's sprinting ×10s in July or grinding ×8s in August.
    /// Launch args (-questFloorSeconds n / -questCeilingSeconds n) override for
    /// demo/verify runs.
    var sessionStart = Date.now   // injectable for -dumpQuestPlan
    private let floorSeconds = SessionViewModel.launchSeconds("-questFloorSeconds", fallback: 12 * 60)
    private let ceilingSeconds = SessionViewModel.launchSeconds("-questCeilingSeconds", fallback: 20 * 60)
    /// Injectable clock (the -dumpQuestPlan simulator advances virtual time).
    var now: () -> Date = { .now }
    var elapsed: TimeInterval { now().timeIntervalSince(sessionStart) }
    /// Facts already pulled forward this session (each gets its preview once).
    private var backfilled = Set<FactID>()
    /// Review serves per fact this session (cap 2 — a small pool must not cycle).
    private var reviewCounts: [FactID: Int] = [:]
    /// Star charge at session start — the bar is renormalized to THIS session's
    /// journey, so every day starts empty and fills completely on its own merit.
    private var startCharge: Double = 0

    /// The Quest Meter: EVERY answer moves it — star-ladder work jumps (70%
    /// weight), everything else advances the session-clock component (30%).
    /// Monotonic via high-water mark; hits 1.0 exactly at quest completion.
    private(set) var questMeter: Double = 0
    private var meterHighWater: Double = 0
    var questComplete: Bool {
        isQuest ? (starEarnedThisSession && elapsed >= floorSeconds)
                : stage == .finished
    }

    private func updateMeter() {
        guard isQuest else { return }
        let raw = starEarnedThisSession ? 1.0 : questCharge
        let starC = startCharge < 1 ? max(0, (raw - startCharge) / (1 - startCharge)) : 1
        let floorC = min(1.0, elapsed / max(floorSeconds, 1))
        meterHighWater = max(meterHighWater, 0.7 * starC + 0.3 * floorC)
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
        self.worldFluent = worldStatBefore.fluent
        self.shownWorldFluent = worldStatBefore.fluent
        self.showsWorldRing = !speedRound && !boss && testFormat == nil && worldStatBefore.total > 0
        let built: [PlannedQuestion]
        if boss {
            built = service.buildBossSession(worldIndex: worldIndex)
        } else if let testFormat {
            built = service.buildTestSession(worldIndex: worldIndex, format: testFormat)
        } else if speedRound {
            built = service.buildSpeedSession()
        } else {
            let quest = service.buildQuestSession()
            built = quest.queue
            questBatch = quest.batch
            let charge = Self.charge(of: quest.batch, service: service)
            questCharge = charge
            startCharge = charge   // bar measures THIS session's journey
        }
        self.queue = built
        self.originalCount = built.count
        for q in built where q.movement != .core { reviewCounts[q.fact, default: 0] += 1 }
        self.masteredBefore = service.activeProfile().masteredCount
        questionStart = .now
        if built.isEmpty { stage = .finished }   // e.g. Speed Round with no fluent facts yet
        updateMeter()   // rollover days start the meter pre-filled where yesterday ended
        updatePhase()   // meter opens already wearing round 1's color (no jolt)
    }

    var current: PlannedQuestion? { index < queue.count ? queue[index] : nil }

    private static func charge(of batch: [FactID], service: LearningService) -> Double {
        guard !batch.isEmpty else { return 0 }
        return batch.map { service.ladderProgress($0) }.reduce(0, +) / Double(batch.count)
    }

    /// Progress: star charge on quest days; queue progress otherwise.
    var progress: Double {
        if isQuest { return starEarnedThisSession ? 1 : questCharge }
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
        if result.becameFluent {
            let filledBefore = WorldStars.filled(fluent: worldFluent, total: worldTotal)
            worldFluent = service.worldStat(at: worldStatBefore.index).fluent
            let filledNow = WorldStars.filled(fluent: worldFluent, total: worldTotal)
            Feedback.fire(.milestone)   // magic shimmer layered over the coin
            // Crossing the star threshold just surges the meter; the slam is the
            // FINALE — it fires at quest completion (see completeQuest), after
            // the bar is full and gold. Quest Complete is what the slam means.
            if filledNow > filledBefore, showsWorldRing {
                starEarnedThisSession = true
                earnedStarIndex = filledNow - 1
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
            if q.format == .recognition {
                var boundary = index + 1
                while boundary < queue.count, queue[boundary].format == .recognition {
                    boundary += 1
                }
                at = min(at, boundary)
            } else {
                while at > 0, at < queue.count,
                      queue[at].format == .recognition,
                      queue[at - 1].format == .recognition {
                    at += 1
                }
            }
            queue.insert(q, at: at)
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

    /// Advance after the neutral-soft reveal. Quest days end when the star has
    /// landed (and the review floor is met); heavy-miss days extend, then roll over.
    func next() {
        guard stage == .feedback else { return }
        index += 1
        skipStaleReps()
        lastSelected = nil

        // Boss dies the moment his HP empties — instant victory, no leftover
        // questions against a corpse.
        if bossWorldIndex != nil, correctCount >= bossHPTotal {
            finish(); return
        }
        if isQuest {
            if questComplete { completeQuest(); return }        // star + time floor
            if elapsed >= ceilingSeconds { completeQuest(); return }   // mercy: star rolls over
            if index >= queue.count {
                // Miss recovery first; then pull tomorrow's material forward
                // (card previews + weak reviews) to fill the session clock.
                var more = service.questExtension(batch: questBatch)
                if more.isEmpty {
                    let capped = Set(reviewCounts.filter { $0.value >= 2 }.keys)
                    more = service.questBackfill(exclude: Set(questBatch).union(backfilled),
                                                 reviewExclude: capped)
                    backfilled.formUnion(more.filter { $0.format == .recognition }.map(\.fact))
                    for q in more where q.movement == .review {
                        reviewCounts[q.fact, default: 0] += 1
                    }
                }
                if more.isEmpty { completeQuest() } else {      // truly out of material
                    queue.append(contentsOf: more)
                    stage = .asking; beginQuestion()
                }
                return
            }
        } else if index >= queue.count {
            finish(); return
        }
        stage = .asking; beginQuestion()
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

    /// Quest over. If a star was earned, the slam overlay is the finale — the
    /// bar is already full and gold — and the wrap follows its dismissal.
    private func completeQuest() {
        shownWorldFluent = worldFluent   // the chip may now show what he earned
        if let star = earnedStarIndex, !questEndPending, auto != .wrap {
            questEndPending = true
            pendingStarEarned = star
        } else {
            finish()
        }
    }

    /// Stop early — full credit for what was done (§6); an earned star still
    /// gets its slam on the way out.
    func stop() {
        guard stage != .finished else { return }
        if isQuest, earnedStarIndex != nil, !questEndPending {
            stage = .feedback   // ensure a consistent state under the overlay
            completeQuest()
        } else {
            finish()
        }
    }

    private func finish() {
        stage = .finished
        shownWorldFluent = worldFluent
        if auto == .wrap { pendingStarEarned = nil }   // demo autoplay: don't trap the wrap
        // Strict flame: dev jumps never count; quests count when the star landed or
        // real time was put in; boss and speed runs always count.
        let practiced = !isTest && (starEarnedThisSession || bossWorldIndex != nil
                                    || isSpeed || elapsed >= 480)
        endCelebration = service.finishSession(
            questionCount: totalAnswered, correctCount: correctCount, xpEarned: xpEarned,
            responseTimes: responseTimes, factsTouched: touched.count,
            speed: isSpeed, bossWorld: bossWorldIndex, practiced: practiced)
        if let bossWorldIndex {
            bossPassed = service.activeProfile().clearedWorlds.contains(bossWorldIndex)
            Feedback.fire(bossPassed ? .levelUp : .wrong)
        }
    }

    var accuracy: Double { totalAnswered == 0 ? 0 : Double(correctCount) / Double(totalAnswered) }
    var showTimer: Bool { timed }
}
