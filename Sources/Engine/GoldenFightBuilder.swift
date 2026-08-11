import Foundation

/// Builds a Golden Guardian fight: the post-map, world-scoped mastery gauntlet.
///
/// Serves EVERY fact the world owns exactly once, each in a format its current
/// stage can actually answer. This is deliberately different from the regular
/// boss pool, whose `introduced && stage >= .recall` filter makes a fact at
/// `.recognition` invisible to every boss fight — which, post-map, would leave
/// a world permanently unconquerable. Here nothing is filtered: a fact the
/// scheduler has never seen is simply served as multiple choice.
public enum GoldenFightBuilder {

    /// The question format a stage can answer in a golden fight.
    /// Recognition stays multiple choice (untimed, a normal hit only — never a
    /// critical, and its time stays out of the speed baseline); recall is open
    /// response untimed; fluency and mastered are open response, timed.
    public static func format(for stage: MasteryStage) -> MasteryStage {
        switch stage {
        case .recognition:        return .recognition
        case .recall:             return .recall
        case .fluency, .mastered: return .fluency
        }
    }

    /// Every fact `worldIndex` owns, exactly once, shuffled, in stage-answerable
    /// formats. Facts missing from `snapshots` or never introduced are served as
    /// recognition: the fight must be able to reach every owned fact from any
    /// reachable profile state.
    public static func build(worldIndex: Int, snapshots: [FactSnapshot],
                             seed: UInt64) -> [PlannedQuestion] {
        let owned = WorldCatalog.facts(inWorld: worldIndex)
        guard !owned.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        var rng = SplitMix64(seed: seed)
        var ids = owned
        ids.shuffle(using: &rng)
        return ids.map { id in
            let stage: MasteryStage
            if let snap = byID[id], snap.introduced { stage = snap.stage }
            else { stage = .recognition }
            let fmt = format(for: stage)
            let prompt = OrientedPrompt(fact: id, swapped: (rng.next() & 1) == 1)
            let options = fmt == .recognition
                ? DistractorGenerator.options(for: prompt, seed: rng.next())
                : nil
            return PlannedQuestion(prompt: prompt, format: fmt, movement: .core,
                                   options: options, timed: fmt == .fluency)
        }
    }
}
