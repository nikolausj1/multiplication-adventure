import Foundation

/// Generates plausible multiple-choice distractors for the Recognition stage (§4.2):
/// near-misses and common confusions, never random. Deterministic given a seed so
/// the same prompt is stable within a session and unit-testable.
public enum DistractorGenerator {

    /// Returns four options (the correct answer plus three distractors), shuffled.
    public static func options(for prompt: OrientedPrompt, seed: UInt64) -> [Int] {
        let answer = prompt.answer
        let f1 = prompt.firstFactor
        let f2 = prompt.secondFactor

        // Candidate plausible wrong answers, ordered by how confusable they are.
        var candidates: [Int] = []
        func add(_ v: Int) {
            if v >= 0, v != answer, !candidates.contains(v) { candidates.append(v) }
        }

        // Off-by-one on each factor (the most common confusion: 7×8 -> 7×7, 7×9, 6×8, 8×8).
        add((f1 + 1) * f2)
        add((f1 - 1) * f2)
        add(f1 * (f2 + 1))
        add(f1 * (f2 - 1))
        // Adjacent products either side.
        add(answer + f1)
        add(answer - f1)
        add(answer + f2)
        add(answer - f2)
        // Digit transposition for two-digit answers (56 -> 65) — a real misread.
        if answer >= 10 {
            let tens = answer / 10, ones = answer % 10
            add(ones * 10 + tens)
        }
        // Off-by-small to guarantee enough plausible fillers near the answer.
        add(answer + 1)
        add(answer - 1)
        add(answer + 2)
        add(answer - 2)

        // Deterministic shuffle of the candidate pool, then take three.
        var rng = SplitMix64(seed: seed)
        candidates.shuffle(using: &rng)
        var distractors = Array(candidates.prefix(3))

        // Safety net: if a degenerate fact (e.g. ×0, ×1) yielded too few, pad upward.
        var pad = answer + 3
        while distractors.count < 3 {
            if pad != answer, !distractors.contains(pad) { distractors.append(pad) }
            pad += 1
        }

        var options = distractors + [answer]
        options.shuffle(using: &rng)
        return options
    }
}

/// Small, fast, seedable PRNG so distractor layout is deterministic and testable
/// without depending on the system RNG.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
