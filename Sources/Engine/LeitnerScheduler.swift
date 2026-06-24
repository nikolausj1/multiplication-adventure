import Foundation

/// Spaced-repetition scheduling (§4.4). The Leitner box governs *when* a fact is
/// due; it is independent of the mastery stage, which governs question format.
public enum LeitnerScheduler {
    public static let maxBox = 6

    /// Indicative intervals per box. Box 0 is "later this same session" (zero days);
    /// box 5+ is treated as mastered and surfaced occasionally for maintenance.
    public static func interval(forBox box: Int) -> TimeInterval {
        let days: Double
        switch max(0, box) {
        case 0:  days = 0      // re-queued within the session, not by date
        case 1:  days = 1
        case 2:  days = 2
        case 3:  days = 4
        case 4:  days = 7
        case 5:  days = 14
        default: days = 30     // maintenance cadence
        }
        return days * 24 * 60 * 60
    }

    /// Next due date after a correct answer promotes the fact one box.
    public static func promote(box: Int, from now: Date) -> (box: Int, due: Date) {
        let next = min(box + 1, maxBox)
        return (next, now.addingTimeInterval(interval(forBox: next)))
    }

    /// A wrong answer drops the fact back several boxes so weak facts get more
    /// exposure, and re-queues it soon (later this same session).
    public static func demote(box: Int, from now: Date) -> (box: Int, due: Date) {
        let next = max(0, box - 2)
        return (next, now)   // due immediately → eligible to re-appear this session
    }

    /// Whether a box is in the "maintenance only" range.
    public static func isMaintenance(box: Int) -> Bool { box >= 5 }
}
