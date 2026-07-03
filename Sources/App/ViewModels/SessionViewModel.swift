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
    private(set) var endCelebration: Celebration?

    /// Debug autoplay (launch-arg gated) for screenshot verification.
    enum AutoMode { case off, feedback, wrap }

    private let service: LearningService
    private let timed: Bool
    private let isSpeed: Bool
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

    init(service: LearningService, speedRound: Bool = false, boss: Bool = false,
         auto: AutoMode = .off, worldIndex: Int = 0, testFormat: MasteryStage? = nil) {
        self.service = service
        // Speed Round, boss challenges, and dev fluency always show the timer;
        // regular practice only when the profile opts into "speed" timing.
        self.timed = speedRound || boss || testFormat == .fluency
            || service.activeProfile().timingMode == .speed
        self.isSpeed = speedRound
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
            built = service.buildSession()
        }
        self.queue = built
        self.originalCount = built.count
        questionStart = .now
        if built.isEmpty { stage = .finished }   // e.g. Speed Round with no fluent facts yet
    }

    var current: PlannedQuestion? { index < queue.count ? queue[index] : nil }

    /// Progress toward the planned target (re-queued misses don't inflate the bar).
    var progress: Double {
        originalCount == 0 ? 1 : min(1, Double(distinctServed) / Double(originalCount))
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
            worldFluent = service.worldStat(at: worldStatBefore.index).fluent
            Feedback.fire(.milestone)   // magic shimmer layered over the coin
        }
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
                      self.pendingCelebration == nil else { return }   // overlay up → wait for its dismissal
                self.next()
            }
        }
    }

    /// Celebration overlay dismissed; if it was holding up a correct-answer
    /// auto-advance, move on now.
    func celebrationDismissed() {
        pendingCelebration = nil
        if stage == .feedback, lastCorrect, auto == .off { next() }
    }

    /// Advance after the neutral-soft reveal.
    func next() {
        guard stage == .feedback else { return }
        index += 1
        lastSelected = nil
        if index >= queue.count { finish() } else { stage = .asking; beginQuestion() }
    }

    /// Stop early — full credit for what was done (§6).
    func stop() { if stage != .finished { finish() } }

    private func finish() {
        stage = .finished
        endCelebration = service.finishSession(
            questionCount: totalAnswered, correctCount: correctCount, xpEarned: xpEarned,
            responseTimes: responseTimes, factsTouched: touched.count,
            speed: isSpeed, bossWorld: bossWorldIndex)
        if let bossWorldIndex {
            bossPassed = service.activeProfile().clearedWorlds.contains(bossWorldIndex)
            Feedback.fire(bossPassed ? .levelUp : .wrong)
        }
    }

    var accuracy: Double { totalAnswered == 0 ? 0 : Double(correctCount) / Double(totalAnswered) }
    var showTimer: Bool { timed }
}
