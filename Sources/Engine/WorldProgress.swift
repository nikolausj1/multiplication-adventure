import Foundation

/// Per-world progress derived from fact snapshots. A world is **cleared** when every
/// fact in it reaches Fluency (reachable, no multi-day wall); true mastery keeps
/// completing in the background and gates only the final certificate.
public struct WorldStat: Sendable, Equatable {
    public let index: Int
    public let total: Int
    public let fluentPlus: Int     // facts at Fluency or Mastered
    public let mastered: Int
    public let introduced: Int
    public var cleared: Bool { total > 0 && fluentPlus == total }
    public var fluentFraction: Double { total == 0 ? 0 : Double(fluentPlus) / Double(total) }
}

public enum WorldProgress {
    public static func stats(snapshots: [FactSnapshot]) -> [WorldStat] {
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        return WorldCatalog.worlds.map { world in
            let facts = WorldCatalog.facts(inWorld: world.index)
            var fluent = 0, mastered = 0, introduced = 0
            for f in facts {
                guard let s = byID[f] else { continue }
                if s.introduced { introduced += 1 }
                if s.stage >= .fluency { fluent += 1 }
                if s.stage == .mastered { mastered += 1 }
            }
            return WorldStat(index: world.index, total: facts.count,
                             fluentPlus: fluent, mastered: mastered, introduced: introduced)
        }
    }

    /// The world the player is currently on: the first not-yet-cleared world (or the
    /// last world once everything is cleared).
    public static func currentIndex(snapshots: [FactSnapshot]) -> Int {
        let s = stats(snapshots: snapshots)
        return s.first(where: { !$0.cleared })?.index ?? (WorldCatalog.count - 1)
    }

    /// Number of fully cleared worlds (for milestone diffing).
    public static func clearedCount(snapshots: [FactSnapshot]) -> Int {
        stats(snapshots: snapshots).filter { $0.cleared }.count
    }

    /// A world is unlocked (visible/playable) if it's the current world or earlier.
    public static func isUnlocked(_ index: Int, snapshots: [FactSnapshot]) -> Bool {
        index <= currentIndex(snapshots: snapshots)
    }
}
