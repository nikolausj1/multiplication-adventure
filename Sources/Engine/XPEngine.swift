import Foundation

/// XP economy (§7). Early on, XP weights *effort* heavily — simply attempting earns
/// well, so resistance stays low and the habit forms. As overall mastery rises, the
/// weighting shifts toward correctness and speed. This is the only place the
/// effort→mastery curve lives; animation intensity is kept separate (two dials).
public enum XPEngine {

    /// `masteryFraction` is facts-mastered / 91, in [0, 1].
    public static func xp(
        correct: Bool,
        responseTime: Double,
        stage: MasteryStage,
        fluencyThreshold: Double,
        masteryFraction: Double
    ) -> Int {
        let t = min(max(masteryFraction, 0), 1)

        // Effort: paid on every attempt, generous early and tapering.
        let attemptBase = lerp(8, 2, t)

        guard correct else { return Int(attemptBase.rounded()) }

        // Correctness: grows as he progresses.
        let correctBonus = lerp(4, 12, t)

        // Speed: only meaningful in the open-response stages, and only when fast.
        var speedBonus = 0.0
        if stage.isOpenResponse, FluencyThreshold.isFast(responseTime, threshold: fluencyThreshold) {
            speedBonus = lerp(0, 8, t)
        }

        return Int((attemptBase + correctBonus + speedBonus).rounded())
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
