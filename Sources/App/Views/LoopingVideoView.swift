import SwiftUI
import AVFoundation
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

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let item = AVPlayerItem(url: url)
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
