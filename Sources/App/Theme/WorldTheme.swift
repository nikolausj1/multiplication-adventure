import SwiftUI
import AVFoundation

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
    var bossVideo: String { "\(world.assetKey)_boss" }

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

    /// The bundled URL for a flat `.mov` resource, or nil if that world has no
    /// video yet (falls back to the still `bossImage`).
    static func videoURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mov")
    }

    private static var videoAspectCache: [String: CGFloat] = [:]

    /// A video's own width/height. Each boss video is cropped to the union
    /// bounding box of its animation, so its aspect differs per world AND from
    /// the matching still — constraining the player to the still's aspect
    /// letterboxes the video inside that box and renders the boss up to 26%
    /// smaller than the space allows. Measured once per name and cached; the
    /// files are local and tiny to interrogate.
    static func videoAspect(_ name: String) -> CGFloat? {
        if let cached = videoAspectCache[name] { return cached }
        guard let url = videoURL(name),
              let track = AVURLAsset(url: url).tracks(withMediaType: .video).first
        else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        let w = abs(size.width), h = abs(size.height)
        guard w > 0, h > 0 else { return nil }
        videoAspectCache[name] = w / h
        return w / h
    }
}
