import Foundation

/// The rank ladder (§7), tied to cumulative facts mastered. Master at the full
/// completion state (§10). Thresholds are a first cut of §14's open question.
public struct Rank: Sendable, Equatable {
    public let index: Int
    public let name: String
    public let masteredThreshold: Int
}

public enum RankLadder {
    public static let ranks: [Rank] = [
        Rank(index: 0, name: "Novice",     masteredThreshold: 0),
        Rank(index: 1, name: "Apprentice", masteredThreshold: 8),
        Rank(index: 2, name: "Builder",    masteredThreshold: 22),
        Rank(index: 3, name: "Skilled",    masteredThreshold: 42),
        Rank(index: 4, name: "Expert",     masteredThreshold: 66),
        Rank(index: 5, name: "Master",     masteredThreshold: FactUniverse.count),
    ]

    public static func rank(forMasteredCount n: Int) -> Rank {
        ranks.last(where: { n >= $0.masteredThreshold }) ?? ranks[0]
    }

    /// The next rank above the current one, if any, plus facts remaining to reach it.
    public static func next(afterMasteredCount n: Int) -> (rank: Rank, remaining: Int)? {
        guard let next = ranks.first(where: { $0.masteredThreshold > n }) else { return nil }
        return (next, next.masteredThreshold - n)
    }

    public static var isComplete: (Int) -> Bool { { $0 >= FactUniverse.count } }
}
