import SwiftUI
import AVFoundation
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

/// Plays a video on seamless, gapless repeat with a transparent background.
/// Generic and reusable — knows nothing about what it's showing.
///
/// Uses `AVQueuePlayer` + `AVPlayerLooper` rather than a single `AVPlayer`
/// with `seek(.zero)` on `.actionAtItemEnd`, which visibly stutters at the
/// loop point.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var isPaused: Bool = false
    /// GOLDEN Guardian fights grade every frame gold in place, per-pixel, via
    /// Core Image — no second video asset. See `goldenComposition` below for
    /// why this is the one place a "filter" is safe to apply to this view.
    var golden: Bool = false

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let item = AVPlayerItem(url: url)
        if golden {
            item.videoComposition = Self.goldenComposition(for: item.asset)
        }
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        queuePlayer.isMuted = true
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false

        view.playerLayer.player = queuePlayer
        view.playerLayer.videoGravity = .resizeAspect
        // Transparency: force a BGRA pixel buffer and turn off the layer's
        // own opacity/background so the alpha channel actually shows through
        // instead of compositing onto a black box.
        view.playerLayer.pixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        view.playerLayer.isOpaque = false
        view.playerLayer.backgroundColor = UIColor.clear.cgColor

        context.coordinator.player = queuePlayer
        context.coordinator.looper = looper
        context.coordinator.installLifecycleObservers()

        queuePlayer.play()
        return view
    }

    /// Grades every frame of an alpha-channel boss video gold, per-pixel, via
    /// `AVMutableVideoComposition`'s Core Image hook — the one filtering route
    /// that does NOT touch the AVPlayerLayer-backed view itself (that's what
    /// destroys alpha; see BossPanel's note). The composition runs inside
    /// AVFoundation's own compositor, upstream of the layer, so the layer still
    /// receives a normal alpha-carrying frame to display.
    ///
    /// The one trap inside the filter chain itself: Core Image's color filters
    /// (CIColorControls, CIColorMatrix) assume PREMULTIPLIED alpha by default.
    /// Run a color matrix on a premultiplied frame and the silhouette edge —
    /// where alpha fades from 1 to 0 — fringes, because the matrix scales the
    /// already-alpha-weighted color rather than the true color. Unpremultiply
    /// before grading, regrade, then premultiply again before handing the
    /// frame back.
    private static func goldenComposition(for asset: AVAsset) -> AVMutableVideoComposition {
        AVMutableVideoComposition(asset: asset) { request in
            let straight = request.sourceImage.unpremultiplyingAlpha()
            let graded = straight
                // Pull toward neutral so the warm tint below reads as a true
                // color grade rather than a tint over the original hues.
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.35,
                    kCIInputBrightnessKey: 0.02,
                    kCIInputContrastKey: 1.08,
                ])
                // Push everything toward warm gold: boost red, hold green,
                // pull blue down and back it off with a small negative bias
                // so shadows don't go muddy-blue.
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.25, y: 0.08, z: 0.00, w: 0),
                    "inputGVector": CIVector(x: 0.12, y: 1.02, z: 0.00, w: 0),
                    "inputBVector": CIVector(x: -0.05, y: 0.00, z: 0.55, w: 0),
                    "inputBiasVector": CIVector(x: 0.035, y: 0.02, z: -0.04, w: 0),
                ])
                .premultiplyingAlpha()
                .cropped(to: request.sourceImage.extent)
            request.finish(with: graded, context: nil)
        }
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        guard let player = context.coordinator.player else { return }
        if isPaused {
            player.pause()
        } else if player.timeControlStatus != .playing {
            player.play()
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        coordinator.looper = nil
        coordinator.player = nil
        coordinator.removeLifecycleObservers()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Backing view whose layer IS an `AVPlayerLayer`, so the layer resizes
    /// with the view automatically instead of needing a manual frame sync.
    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?

        func installLifecycleObservers() {
            #if canImport(UIKit)
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.player?.pause() }
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.player?.play() }
            #endif
        }

        func removeLifecycleObservers() {
            if let o = backgroundObserver { NotificationCenter.default.removeObserver(o) }
            if let o = foregroundObserver { NotificationCenter.default.removeObserver(o) }
            backgroundObserver = nil
            foregroundObserver = nil
        }
    }
}
