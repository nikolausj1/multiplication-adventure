import Foundation

/// Drives one True/False Lightning Round: a fast, fluent-facts-only consolidation
/// pass. Deliberately does NOT touch the learning engine's scheduler/Leitner/
/// promotion pipeline — see `LearningService.finishLightningRound`. Structurally
/// mirrors `SessionViewModel`'s asking/feedback/finished shape, but is its own,
/// much smaller state machine (no quest meter, no boss, no re-queueing).
@MainActor
@Observable
final class LightningRoundViewModel {
    enum Stage { case asking, feedback, finished }

    private(set) var statements: [LightningRound.Statement] = []
    private(set) var index = 0
    private(set) var stage: Stage = .asking

    private(set) var correctCount = 0
    private(set) var lastCorrect = false
    private(set) var lastSelectedTrue: Bool?
    private(set) var elapsed: Double = 0
    private(set) var xpEarned = 0
    private(set) var isNewBest = false
    /// True when the fluent-facts pool was empty at launch — nothing to play.
    private(set) var unavailable = false

    var pendingCelebration: Celebration?

    private let service: LearningService
    private let auto: Bool
    private let startedAt = Date.now
    private var feedbackGen = 0

    var total: Int { statements.count }
    var current: LightningRound.Statement? { index < statements.count ? statements[index] : nil }

    /// `auto` drives a debug autoplay (always answers correctly) so the results
    /// screen is reachable for screenshot verification without manual taps —
    /// mirrors the app's existing `-demoWrap` / `-demoFeedback` conventions.
    init(service: LearningService, seed: UInt64? = nil, auto: Bool = false) {
        self.service = service
        self.auto = auto
        let pool = service.lightningPool()
        let s = seed ?? UInt64(bitPattern: Int64(Date.now.timeIntervalSince1970))
        self.statements = LightningRound.build(pool: pool, seed: s)
        if statements.isEmpty {
            unavailable = true
            stage = .finished
        } else {
            beginAutoplayIfNeeded()
        }
    }

    func answer(_ selectedTrue: Bool) {
        guard stage == .asking, let s = current else { return }
        let correct = selectedTrue == s.isTrue
        lastSelectedTrue = selectedTrue
        lastCorrect = correct
        if correct { correctCount += 1 }
        Feedback.fire(correct ? .correct : .wrong)
        stage = .feedback
        feedbackGen += 1
        let gen = feedbackGen
        // Fast pace, minimal dwell (§ spec): a correct tap snaps forward in
        // ≤200ms; a miss holds just long enough to read the true equation
        // (neutral-soft reveal, no punishment beat) before auto-advancing.
        let delay = correct ? 0.18 : 0.9
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.stage == .feedback, self.feedbackGen == gen else { return }
            self.advance()
        }
    }

    private func advance() {
        index += 1
        lastSelectedTrue = nil
        if index >= statements.count { finish(); return }
        stage = .asking
        beginAutoplayIfNeeded()
    }

    private func beginAutoplayIfNeeded() {
        guard auto, stage == .asking else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.stage == .asking, let s = self.current else { return }
            self.answer(s.isTrue)   // always correct, so the demo run completes cleanly
        }
    }

    private func finish() {
        elapsed = Date.now.timeIntervalSince(startedAt)
        stage = .finished
        Feedback.fire(.complete)
        let celebration = service.finishLightningRound(correct: correctCount,
                                                        total: statements.count, elapsed: elapsed)
        xpEarned = correctCount * LearningService.lightningXPPerCorrect
        isNewBest = celebration != nil
        pendingCelebration = celebration
    }

    func celebrationDismissed() { pendingCelebration = nil }
}
