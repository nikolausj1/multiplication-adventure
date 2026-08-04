import AVFoundation
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: url)
let tracks = asset.tracks(withMediaType: .video)
print("file:", url.lastPathComponent)
print("video tracks:", tracks.count)
for t in tracks {
    print("  trackID \(t.trackID)  naturalSize \(t.naturalSize)")
    print("  >>> hasMediaCharacteristic(.containsAlphaChannel): \(t.hasMediaCharacteristic(.containsAlphaChannel))")
    for fd in t.formatDescriptions {
        let d = fd as! CMFormatDescription
        let st = CMFormatDescriptionGetMediaSubType(d)
        let chars = withUnsafeBytes(of: st.bigEndian) { String(bytes: $0, encoding: .ascii) ?? "?" }
        print("  subType: \(chars)")
        if let ext = CMFormatDescriptionGetExtensions(d) as? [String: Any] {
            for k in ext.keys.sorted() where k.lowercased().contains("alpha") || k.lowercased().contains("depth") {
                print("    ext[\(k)] = \(ext[k]!)")
            }
            print("    all ext keys: \(ext.keys.sorted().joined(separator: ", "))")
        }
    }
}
