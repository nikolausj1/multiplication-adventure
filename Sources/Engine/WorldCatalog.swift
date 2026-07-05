import Foundation

/// A world in the Multiplication Adventure map. Identity is data-driven so art and
/// names can change without touching logic. Names are placeholders.
public struct World: Sendable, Equatable {
    public let index: Int          // 0-based
    public let name: String
    public let bossName: String    // the world's guardian (boss challenge)
    public let assetKey: String    // e.g. "world1" → world1_bg / world1_node / world1_button
    public let slots: [Int]        // curriculum slot indices this world owns
    public let palette: WorldPalette

    public var number: Int { index + 1 }
}

/// Per-world colors (hex strings; converted to Color in the app's theme layer).
public struct WorldPalette: Sendable, Equatable {
    public let primary: String
    public let accent: String
    public let deep: String
    public init(_ primary: String, _ accent: String, _ deep: String) {
        self.primary = primary; self.accent = accent; self.deep = deep
    }
}

/// The 7-world journey. Worlds map onto contiguous curriculum slots (§5), front-loaded
/// easy, hard tables solo. New learning is scoped per world; review is cumulative.
public enum WorldCatalog {
    public static let worlds: [World] = [
        World(index: 0, name: "Highland Trail",  bossName: "Granite Giant",
              assetKey: "world1", slots: [0, 1, 2, 3],
              palette: WorldPalette("#6BBF59", "#FFD23F", "#3B6B2E")),
        World(index: 1, name: "Shipwreck Cove",  bossName: "Tidal Kraken",
              assetKey: "world2", slots: [4, 5],
              palette: WorldPalette("#2EC4B6", "#FFE3A3", "#155E63")),
        World(index: 2, name: "Jungle Temple",   bossName: "Jade Jaguar",
              assetKey: "world3", slots: [6, 7],
              palette: WorldPalette("#2F7D32", "#FFC107", "#173B1A")),
        World(index: 3, name: "Desert Canyon",   bossName: "Sandstorm Scorpion",
              assetKey: "world4", slots: [8],
              palette: WorldPalette("#E8B04B", "#28C2C2", "#8A5A22")),
        World(index: 4, name: "Frozen Summit",   bossName: "FrostFang Dragon",
              assetKey: "world5", slots: [9],
              palette: WorldPalette("#5FB0E5", "#B388FF", "#1E3A5F")),
        World(index: 5, name: "Volcano Depths",  bossName: "Magma Fist",
              assetKey: "world6", slots: [10],
              palette: WorldPalette("#FF7A18", "#FFC93C", "#3A2C2A")),
        World(index: 6, name: "Sky Citadel",     bossName: "Storm Titan",
              assetKey: "world7", slots: [11],
              palette: WorldPalette("#5B4B8A", "#FFD24C", "#2A2350")),
    ]

    public static var count: Int { worlds.count }

    /// Which world introduces a given fact (the world owning the fact's curriculum slot).
    public static func worldIndex(ofFact fact: FactID) -> Int {
        let slot = Curriculum.slot(of: fact)
        return worlds.first(where: { $0.slots.contains(slot) })?.index ?? worlds.count - 1
    }

    public static func facts(inWorld index: Int) -> [FactID] {
        FactUniverse.allFacts.filter { worldIndex(ofFact: $0) == index }
    }

    /// The highest curriculum slot owned by a world (for gating new-fact introduction).
    public static func maxSlot(forWorld index: Int) -> Int {
        worlds[safe: index]?.slots.max() ?? Curriculum.tableOrder.count - 1
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
