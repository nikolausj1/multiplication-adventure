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
    private(set) var justMastered = false

    // Running session stats.
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
    private let auto: AutoMode
    private var questionStart = Date.now
    private let originalCount: Int

    init(service: LearningService, speedRound: Bool = false, auto: AutoMode = .off) {
        self.service = service
        self.timed = speedRound
        self.auto = auto
        let built = speedRound ? service.buildSpeedSession() : service.buildSession()
        self.queue = built
        self.originalCount = built.count
        questionStart = .now
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
        responseTimes.append(rt)
        xpEarned += result.xp

        lastCorrect = correct
        lastSelected = value
        lastCorrectAnswer = q.prompt.answer
        lastXP = result.xp
        justMastered = result.becameMastered
        Feedback.fire(correct ? .correct : .wrong)
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
            responseTimes: responseTimes, factsTouched: touched.count, speed: timed)
    }

    var accuracy: Double { totalAnswered == 0 ? 0 : Double(correctCount) / Double(totalAnswered) }
    var showTimer: Bool { timed }
}
