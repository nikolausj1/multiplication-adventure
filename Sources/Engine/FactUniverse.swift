import Foundation

/// The fact universe (§4.1): the unique pairs from 0×0 through the 11s, first
/// factor ≤ second. Capped for entering-4th-grade fluency: no ×12 table, and
/// 11×11 is out of scope too — 11×10 is the summit. 77 facts.
public enum FactUniverse {
    public static let minFactor = 0
    public static let maxFactor = 11

    /// All 77 canonical facts, in a stable order (sorted by the larger factor then smaller).
    public static let allFacts: [FactID] = {
        var facts: [FactID] = []
        for b in minFactor...maxFactor {
            for a in minFactor...b {
                facts.append(FactID(a, b))
            }
        }
        return facts.sorted().filter { $0 != FactID(11, 11) }
    }()

    public static var count: Int { allFacts.count }   // 77
}
