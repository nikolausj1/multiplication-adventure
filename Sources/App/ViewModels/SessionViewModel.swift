import SwiftUI
import SwiftData

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
    var worldTotal: Int { worldStatBefore.total }
    /// The ring only makes sense in a regular progression session.
    let showsWorldRing: Bool

    /// Set for a world-boss challenge run; the wrap uses `bossPassed` for its verdict.
    let bossWorldIndex: Int?
    private(set) var bossPassed = false
    /// Correct answers needed to visually defeat the guardian (the pass bar).
    var bossHPTotal: Int {
        max(1, Int(ceil(Double(originalCount) * LearningService.bossPassAccuracy)))
    }

    /// Star Quest state: today's batch of facts being drilled to fluent. Empty for
    /// boss/speed/test runs and boss-pending review days.
    private(set) var questBatch: [FactID] = []
    private(set) var starEarnedThisSession = false
    /// Ladder charge of today's star in [0, 1] — drives the top progress bar.
    private(set) var questCharge: Double = 0
    var isQuest: Bool { !questBatch.isEmpty }
    private let questFloor = 15        // never fewer answers than this (when review exists)
    private let questCeiling = 80      // hard stop; the star rolls over to tomorrow

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
        self.auto = auto
        self.worldStatBefore = service.currentWorldStat()
        self.worldFluent = worldStatBefore.fluent
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
            questCharge = Self.charge(of: quest.batch, service: service)
        }
        self.queue = built
        self.originalCount = built.count
        questionStart = .now
        if built.isEmpty { stage = .finished }   // e.g. Speed Round with no fluent facts yet
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
        guard auto != .off else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.stage == .asking, let q = self.current else { return }
            self.answer(q.prompt.answer)
            if self.auto == .wrap {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.next() }
            }
        }
    }

    func answer(_ value: Int) {
        guard stage == .asking, let q = current else { return }
        let rt = Date.now.timeIntervalSince(questionStart)
        let correct = value == q.prompt.answer

        let result = service.record(prompt: q.prompt, format: q.format,
                                    correct: correct, responseTime: rt)
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
        Feedback.fire(correct ? .correct : .wrong, combo: combo)
        if result.becameFluent {
            let filledBefore = WorldStars.filled(fluent: worldFluent, total: worldTotal)
            worldFluent = service.worldStat(at: worldStatBefore.index).fluent
            let filledNow = WorldStars.filled(fluent: worldFluent, total: worldTotal)
            Feedback.fire(.milestone)   // magic shimmer layered over the coin
            // Crossing a star threshold takes over the screen (slam-into-socket).
            if filledNow > filledBefore, showsWorldRing {
                pendingStarEarned = filledNow - 1
                starEarnedThisSession = true
            }
        }
        if isQuest { questCharge = Self.charge(of: questBatch, service: service) }
        if let c = result.celebration {
            pendingCelebration = c
            Feedback.fire(c.tier >= .t3 ? .milestone : .levelUp)
        }

        // A wrong answer re-queues the fact a few slots later (§4.4).
        if !correct {
            let insertAt = min(index + 4, queue.count)
            queue.insert(q, at: insertAt)
        }
        stage = .feedback
        feedbackGen += 1

        // Correct answers keep the flow: advance automatically after a beat.
        // Misses wait for an explicit Continue so the reveal actually lands.
        if correct, auto == .off {
            let gen = feedbackGen
            let delay = (justMastered || justFluent) ? 1.6 : 0.9   // let the ring moment land
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

    /// Star-earned overlay dismissed; resume the flow.
    func starEarnedDismissed() {
        pendingStarEarned = nil
        if stage == .feedback, lastCorrect, auto == .off, pendingCelebration == nil { next() }
    }

    /// Debug (launch-arg): show the star-earned overlay without earning one.
    func debugShowStar(_ index: Int) { pendingStarEarned = index }

    /// Advance after the neutral-soft reveal. Quest days end when the star has
    /// landed (and the review floor is met); heavy-miss days extend, then roll over.
    func next() {
        guard stage == .feedback else { return }
        index += 1
        lastSelected = nil

        if isQuest {
            if starEarnedThisSession && totalAnswered >= min(questFloor, queue.count) {
                finish(); return
            }
            if totalAnswered >= questCeiling { finish(); return }   // star rolls over
            if index >= queue.count {
                let ext = service.questExtension(batch: questBatch)
                if ext.isEmpty { finish() } else {
                    queue.append(contentsOf: ext)
                    stage = .asking; beginQuestion()
                }
                return
            }
        } else if index >= queue.count {
            finish(); return
        }
        stage = .asking; beginQuestion()
    }

    /// Stop early — full credit for what was done (§6).
    func stop() { if stage != .finished { finish() } }

    private func finish() {
        stage = .finished
        if auto == .wrap { pendingStarEarned = nil }   // demo autoplay: don't trap the wrap
        // Strict flame: dev jumps never count; quests count when the star landed or
        // real effort was put in; boss and speed runs always count.
        let practiced = !isTest && (starEarnedThisSession || bossWorldIndex != nil
                                    || isSpeed || totalAnswered >= questFloor)
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
