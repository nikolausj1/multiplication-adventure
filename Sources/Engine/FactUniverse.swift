import Foundation

/// The fact universe (§4.1): the 91 unique pairs from 0×0 through 12×12 where
/// the first factor is ≤ the second.
public enum FactUniverse {
    public static let minFactor = 0
    public static let maxFactor = 12

    /// All 91 canonical facts, in a stable order (sorted by the larger factor then smaller).
    public static let allFacts: [FactID] = {
        var facts: [FactID] = []
        for b in minFactor...maxFactor {
            for a in minFactor...b {
                facts.append(FactID(a, b))
            }
        }
        return facts.sorted()
    }()

    public static var count: Int { allFacts.count }   // 91
}
