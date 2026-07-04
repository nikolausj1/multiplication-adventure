import Foundation

/// Applies the promotion and mastery rules (§4.3) plus Leitner box movement (§4.4)
/// and telemetry (§4.5) to a fact after an answer. Pure: returns a new snapshot.
public enum PromotionEngine {
    static let recentTimesCap = 12
    static let recognitionGoal = 2   // consecutive correct MC
    static let recallGoal = 3        // correct open responses
    static let fluencyGoal = 3       // fast-correct open responses
    static let fluencyDaysGoal = 2   // across at least this many calendar days

    public struct Outcome: Sendable, Equatable {
        public var snapshot: FactSnapshot
        public var promotedStage: Bool        // moved up a stage this answer
        public var becameMastered: Bool
        public var lapsed: Bool               // a mastered fact slipped
    }

    /// `countsTime: false` records correctness but keeps the response time out of
    /// the speed baseline (used for inverse-form questions, which are naturally slower).
    public static func apply(
        to s: FactSnapshot,
        correct: Bool,
        responseTime: Double,
        fluencyThreshold: Double,
        now: Date,
        countsTime: Bool = true
    ) -> Outcome {
        var f = s
        f.introduced = true
        f.totalAttempts += 1
        f.lastSeen = now
        let priorStage = f.stage

        if correct {
            f.totalCorrect += 1
            if countsTime {
                f.recentTimes.append(responseTime)
                if f.recentTimes.count > recentTimesCap {
                    f.recentTimes.removeFirst(f.recentTimes.count - recentTimesCap)
                }
                f.averageTime = f.recentTimes.reduce(0, +) / Double(f.recentTimes.count)
            }

            let promoted = LeitnerScheduler.promote(box: f.box, from: now)
            f.box = promoted.box
            f.dueDate = promoted.due

            switch f.stage {
            case .recognition:
                f.recognitionStreak += 1
                if f.recognitionStreak >= recognitionGoal { advance(&f, to: .recall) }
            case .recall:
                f.recallCorrect += 1
                if f.recallCorrect >= recallGoal { advance(&f, to: .fluency) }
            case .fluency:
                if FluencyThreshold.isFast(responseTime, threshold: fluencyThreshold) {
                    f.fluencyFastCount += 1
                    f.fluencyFastDays.insert(DayStamp.of(now))
                }
                if f.fluencyFastCount >= fluencyGoal && f.fluencyFastDays.count >= fluencyDaysGoal {
                    advance(&f, to: .mastered)
                    f.masteredDate = now
                }
            case .mastered:
                break   // maintenance rep; stays mastered, box already promoted
            }
        } else {
            f.lastErrorDate = now
            let demoted = LeitnerScheduler.demote(box: f.box, from: now)
            f.box = demoted.box
            f.dueDate = demoted.due

            switch f.stage {
            case .recognition:
                f.recognitionStreak = 0
            case .recall:
                f.recallCorrect = 0          // "no recent error" → progress resets
            case .fluency:
                f.recognitionStreak = 0
                f.recallCorrect = 0
            case .mastered:
                // A lapse: a mastered fact returns to review, never to zero (§4, §11).
                f.stage = .fluency
                f.fluencyFastCount = 0
                f.fluencyFastDays = []
                f.lapseCount += 1
            }
        }

        return Outcome(
            snapshot: f,
            promotedStage: f.stage > priorStage,
            becameMastered: f.stage == .mastered && priorStage != .mastered,
            lapsed: priorStage == .mastered && f.stage < .mastered
        )
    }

    private static func advance(_ f: inout FactSnapshot, to stage: MasteryStage) {
        f.stage = stage
        f.recognitionStreak = 0
        f.recallCorrect = 0
    }
}
