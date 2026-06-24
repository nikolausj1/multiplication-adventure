import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Haptics + sound hooks, routed through the token layer. Sound is a stub wired to
/// fire 1:1 with motion events; drop a ~6–8 clip pack into Resources and map here.
enum Feedback {
    static var soundEnabled = true

    enum Event {
        case correct, wrong, keyTap, levelUp, milestone, complete
    }

    static func fire(_ event: Event) {
        #if canImport(UIKit)
        switch event {
        case .correct:   impact(.light)
        case .wrong:     impact(.soft)
        case .keyTap:    selection()
        case .levelUp:   notify(.success)
        case .milestone: notify(.success)
        case .complete:  notify(.success)
        }
        #endif
        // Sound: intentionally a no-op until the audio pack lands (fast-follow).
    }

    #if canImport(UIKit)
    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style); g.impactOccurred()
    }
    private static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    #endif
}
