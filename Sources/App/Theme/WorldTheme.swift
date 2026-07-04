import SwiftUI

/// Maps a pure-engine `World` to SwiftUI colors and asset names. This is the swap
/// point between the data-driven world catalog and the actual art/palette.
struct WorldTheme: Equatable {
    let world: World

    var primary: Color { Color(hex: world.palette.primary) }
    var accent: Color { Color(hex: world.palette.accent) }
    var deep: Color { Color(hex: world.palette.deep) }

    var bgImage: String { "\(world.assetKey)_bg" }
    var nodeImage: String { "\(world.assetKey)_node" }
    var buttonImage: String { "\(world.assetKey)_button" }
    var bossImage: String { "\(world.assetKey)_boss" }

    static func forWorld(_ index: Int) -> WorldTheme {
        WorldTheme(world: WorldCatalog.worlds[min(max(index, 0), WorldCatalog.count - 1)])
    }
}

private struct WorldThemeKey: EnvironmentKey {
    static let defaultValue = WorldTheme.forWorld(0)
}
extension EnvironmentValues {
    var worldTheme: WorldTheme {
        get { self[WorldThemeKey.self] }
        set { self[WorldThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        } else { r = 0.5; g = 0.5; b = 0.5 }
        self.init(red: r, green: g, blue: b)
    }
}

/// True if an image asset exists in the bundle (so views can fall back to palette
/// placeholders before the art is added).
enum Art {
    static func exists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}
