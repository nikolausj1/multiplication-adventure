import Foundation

/// Adaptive weak-area detection (§4.5). Computes a per-fact priority so that slow,
/// error-prone, overdue, or recently lapsed facts get more airtime, while fast and
/// reliable facts get less. Higher score = more deserving of practice now.
public enum PriorityCalculator {

    public static func priority(of f: FactSnapshot, now: Date, fluencyThreshold: Double) -> Double {
        guard f.introduced else { return 0 }

        var score = 0.0

        // Overdue-ness: how far past due, in days (capped).
        let overdueDays = max(0, now.timeIntervalSince(f.dueDate) / 86_400)
        score += min(overdueDays, 14) * 2.0

        // Low accuracy pushes priority up.
        if f.totalAttempts > 0 {
            score += (1.0 - f.accuracy) * 10.0
        } else {
            score += 6.0   // never-attempted-but-introduced facts deserve a look
        }

        // Slowness relative to the fluency bar.
        if f.averageTime > 0 {
            let slowness = max(0, f.averageTime - fluencyThreshold)
            score += min(slowness, 5) * 1.5
        }

        // Recent lapses are urgent.
        score += Double(f.lapseCount) * 3.0

        // Recent error within the last few days.
        if let err = f.lastErrorDate, now.timeIntervalSince(err) < 3 * 86_400 {
            score += 4.0
        }

        // Earlier stages need more reps to climb.
        score += Double(MasteryStage.mastered.rawValue - f.stage.rawValue) * 1.0

        return score
    }
}
