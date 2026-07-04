import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// Haptics + sound, routed through one place. Sounds play 1:1 with motion events.
/// Drop `sfx_*.wav` files into Resources/Audio and they play automatically; until
/// then this is haptics-only (no-op audio).
enum Feedback {
    static var soundEnabled = true

    enum Event {
        case correct, wrong, keyTap, levelUp, milestone, complete
        case bossHit, bossDefeat
        case phaseJolt   // Quest Meter electric zap at a phase transition
    }

    static func fire(_ event: Event, combo: Int = 0) {
        haptic(event)
        guard soundEnabled, let name = soundName(event, combo: combo) else { return }
        play(name)
    }

    private static func soundName(_ e: Event, combo: Int) -> String? {
        switch e {
        case .correct:
            // Streaks climb a major chord (coin pitched +4/+7/+12 semitones).
            switch combo {
            case ..<3:  return "sfx_correct"
            case 3...4: return "sfx_correct2"
            case 5...7: return "sfx_correct3"
            default:    return "sfx_correct4"
            }
        case .wrong:      return "sfx_wrong"
        case .keyTap:     return "sfx_key"
        case .levelUp:    return "sfx_world_unlock"
        case .milestone:  return "sfx_milestone"
        case .complete:   return "sfx_complete"
        case .bossHit:    return "sfx_boss_hit"
        case .bossDefeat: return "sfx_boss_defeat"
        case .phaseJolt:  return "sfx_phase_zap"
        }
    }

    // MARK: Audio

    private static var players: [String: AVAudioPlayer] = [:]
    private static var sessionReady = false

    private static func play(_ name: String) {
        prepareSession()
        if let p = players[name] { p.currentTime = 0; p.play(); return }
        for ext in ["wav", "caf", "m4a", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay(); players[name] = p; p.play(); return
            }
        }
        // No audio asset yet → silently skip (haptics already fired).
    }

    private static func prepareSession() {
        #if canImport(UIKit)
        guard !sessionReady else { return }
        // .ambient so the app never interrupts the child's music/podcast.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionReady = true
        #endif
    }

    // MARK: Haptics

    private static func haptic(_ event: Event) {
        #if canImport(UIKit)
        switch event {
        case .correct:   impact(.light)
        case .wrong:     impact(.soft)
        case .keyTap:    UISelectionFeedbackGenerator().selectionChanged()
        case .levelUp:   notify(.success)
        case .milestone: notify(.success)
        case .complete:  notify(.success)
        case .bossHit:   impact(.medium)
        case .bossDefeat: notify(.success)
        case .phaseJolt: impact(.rigid)
        }
        #endif
    }

    #if canImport(UIKit)
    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style); g.impactOccurred()
    }
    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    #endif
}
