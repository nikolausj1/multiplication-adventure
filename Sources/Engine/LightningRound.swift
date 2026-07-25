import Foundation

/// The True/False Lightning Round: a fast "freshness" consolidation pass, not new
/// teaching. Twenty true/false statements built ONLY from fluent-or-better facts,
/// ~50/50 true/false (randomized order, never strictly alternating), false
/// statements using plausible near-miss products (never a negative or absurd
/// value). Pure and seeded — no engine/scheduler side effects; the caller (the
/// app layer) decides what, if anything, to record from the results.
public enum LightningRound {

    /// One shown statement: "a × b = shownValue — true or false?"
    public struct Statement: Sendable, Equatable {
        public let prompt: OrientedPrompt
        public let shownValue: Int

        public var fact: FactID { prompt.fact }
        public var isTrue: Bool { shownValue == prompt.answer }
        public var displayText: String { "\(prompt.firstFactor) × \(prompt.secondFactor) = \(shownValue)" }
        /// The true equation — shown on a miss (neutral-soft reveal, never the
        /// possibly-false statement the child just answered).
        public var trueEquationText: String { "\(prompt.text) = \(prompt.answer)" }
    }

    public static let roundLength = 20

    /// Builds a round from a pool of fluent-or-better fact IDs. Facts repeat if the
    /// pool is smaller than the round length, but never twice in a row. An empty
    /// pool returns an empty round — the caller shows a friendly "not ready yet"
    /// state rather than crashing on a zero-length round.
    public static func build(pool: [FactID], seed: UInt64, count: Int = roundLength) -> [Statement] {
        guard !pool.isEmpty, count > 0 else { return [] }
        var rng = SplitMix64(seed: seed)

        // Fact picks: repeated shuffled passes over the pool. Within a pass every
        // fact appears once, so at most the pass-leading fact can collide with the
        // previous pass's trailing fact — skip it there (it reappears later in the
        // same pass once `picks.last` has moved on).
        var picks: [FactID] = []
        while picks.count < count {
            for f in pool.shuffled(using: &rng) {
                guard picks.count < count else { break }
                if f == picks.last, pool.count > 1 { continue }
                picks.append(f)
            }
        }

        // ~50/50 split; shuffled placement so it never strictly alternates.
        let trueCount = (picks.count + 1) / 2
        var truthFlags = Array(repeating: true, count: trueCount)
            + Array(repeating: false, count: picks.count - trueCount)
        truthFlags.shuffle(using: &rng)

        return picks.enumerated().map { i, factID in
            let prompt = OrientedPrompt(fact: factID, swapped: (rng.next() & 1) == 1)
            let shown = truthFlags[i] ? prompt.answer : plausibleFalseValue(for: prompt, seed: rng.next())
            return Statement(prompt: prompt, shownValue: shown)
        }
    }

    /// A plausible wrong product for a false statement: off-by-one on one operand
    /// (a neighboring table's row — e.g. 7×8 → 6×8, 8×8, 7×7, 7×9), or off-by-small
    /// on the shown product itself (±1...±4). Never negative, never equal to the
    /// true product.
    static func plausibleFalseValue(for prompt: OrientedPrompt, seed: UInt64) -> Int {
        let answer = prompt.answer
        let f1 = prompt.firstFactor, f2 = prompt.secondFactor
        var candidates: [Int] = []
        func add(_ v: Int) { if v >= 0, v != answer, !candidates.contains(v) { candidates.append(v) } }

        add((f1 + 1) * f2)
        if f1 > 0 { add((f1 - 1) * f2) }
        add(f1 * (f2 + 1))
        if f2 > 0 { add(f1 * (f2 - 1)) }
        for d in 1...4 {
            add(answer + d)
            add(answer - d)
        }

        var rng = SplitMix64(seed: seed)
        candidates.shuffle(using: &rng)
        return candidates.first ?? (answer + 1)
    }
}
