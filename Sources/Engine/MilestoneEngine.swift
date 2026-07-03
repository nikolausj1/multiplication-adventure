import Foundation

/// Celebration intensity tiers (locked design taxonomy). Intensity is set by a
/// milestone's rarity × effort, kept separate from the XP curve.
public enum CelebrationTier: Int, Sendable, Comparable {
    case t0 = 0   // in-loop feedback (not a celebration)
    case t1       // light ack: mastered fact, daily streak, wrap, speed PB
    case t2       // medium: rank-up, table complete, streak threshold
    case t3       // major: 25 / 50 / 75%
    case t4       // finale: 100%
    public static func < (l: CelebrationTier, r: CelebrationTier) -> Bool { l.rawValue < r.rawValue }
}

public enum MilestoneKind: Equatable, Sendable {
    case factMastered
    case streakContinued(days: Int)
    case streakThreshold(days: Int)
    case worldCleared(name: String)
    case tableComplete(factor: Int)
    case overallPercent(Int)       // 25 / 50 / 75
    case completion
}

public struct MilestoneEvent: Equatable, Sendable {
    public let kind: MilestoneKind
    public let tier: CelebrationTier
    public let message: String
}

/// A single celebration to play, after coincident events are merged into one
/// (highest tier wins; the others fold into its lines).
public struct Celebration: Equatable, Sendable {
    public let tier: CelebrationTier
    public let headline: String
    public let lines: [String]
}

public struct ProgressAggregate: Equatable, Sendable {
    public var masteredCount: Int
    public var completedFactors: Set<Int>
    public var clearedWorlds: Int
    public var streakDays: Int

    public init(masteredCount: Int, completedFactors: Set<Int>, clearedWorlds: Int, streakDays: Int) {
        self.masteredCount = masteredCount
        self.completedFactors = completedFactors
        self.clearedWorlds = clearedWorlds
        self.streakDays = streakDays
    }

    public static func from(snapshots: [FactSnapshot], streakDays: Int) -> ProgressAggregate {
        let mastered = snapshots.filter { $0.stage == .mastered }
        let masteredIDs = Set(mastered.map { $0.id })
        var completed: Set<Int> = []
        for f in FactUniverse.minFactor...FactUniverse.maxFactor {
            let factsWithF = FactUniverse.allFacts.filter { $0.a == f || $0.b == f }
            if factsWithF.allSatisfy({ masteredIDs.contains($0) }) { completed.insert(f) }
        }
        return ProgressAggregate(
            masteredCount: mastered.count,
            completedFactors: completed,
            clearedWorlds: WorldProgress.clearedCount(snapshots: snapshots),
            streakDays: streakDays
        )
    }
}

public enum MilestoneEngine {
    static let streakThresholds = [3, 7, 14, 30]
    static let percentCounts: [(pct: Int, count: Int)] = [
        (25, 23), (50, 46), (75, 69),
    ]

    /// Diff two aggregates and return every milestone crossed.
    public static func events(before: ProgressAggregate, after: ProgressAggregate) -> [MilestoneEvent] {
        var events: [MilestoneEvent] = []

        if after.masteredCount >= FactUniverse.count && before.masteredCount < FactUniverse.count {
            events.append(.init(kind: .completion, tier: .t4,
                                message: "You know your multiplication tables!"))
            // Completion supersedes everything else; nothing below would add value.
            return events
        }

        for (pct, count) in percentCounts where before.masteredCount < count && after.masteredCount >= count {
            events.append(.init(kind: .overallPercent(pct), tier: .t3,
                                message: "\(pct)% of all facts mastered"))
        }

        if after.clearedWorlds > before.clearedWorlds {
            for i in before.clearedWorlds..<after.clearedWorlds {
                let name = WorldCatalog.worlds[safe: i]?.name ?? "World \(i + 1)"
                events.append(.init(kind: .worldCleared(name: name), tier: .t3,
                                    message: "You cleared \(name)!"))
            }
        }

        for factor in after.completedFactors.subtracting(before.completedFactors).sorted() {
            events.append(.init(kind: .tableComplete(factor: factor), tier: .t2,
                                message: "You finished the ×\(factor) table!"))
        }

        if after.streakDays > before.streakDays {
            if streakThresholds.contains(after.streakDays) {
                events.append(.init(kind: .streakThreshold(days: after.streakDays), tier: .t2,
                                    message: "\(after.streakDays)-day streak!"))
            } else {
                events.append(.init(kind: .streakContinued(days: after.streakDays), tier: .t1,
                                    message: after.streakDays == 1 ? "Practiced today!"
                                                                   : "\(after.streakDays) days in a row"))
            }
        }

        return events
    }

    /// Merge coincident events into one celebration at the highest tier; lower-tier
    /// messages fold into the lines. Returns nil if nothing worth interrupting for.
    public static func merge(_ events: [MilestoneEvent], minTier: CelebrationTier = .t1) -> Celebration? {
        let worthy = events.filter { $0.tier >= minTier }
        guard let top = worthy.map(\.tier).max() else { return nil }
        let ordered = worthy.sorted { $0.tier > $1.tier }
        let headline = ordered.first?.message ?? ""
        let lines = ordered.dropFirst().map(\.message)
        return Celebration(tier: top, headline: headline, lines: Array(lines))
    }
}
