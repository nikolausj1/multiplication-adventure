import Foundation

/// The three-stage mastery model (§4.2). A fact's stage decides the *format* of
/// the question it is asked in; the Leitner box (separate) decides *when* it is due.
public enum MasteryStage: Int, Codable, Sendable, CaseIterable, Comparable {
    case recognition = 0   // multiple choice
    case recall      = 1   // open response, untimed pressure
    case fluency     = 2   // open response, speed matters
    case mastered    = 3   // durable; surfaced only for maintenance

    public static func < (lhs: MasteryStage, rhs: MasteryStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The badge number shown on the mastery grid (1–3); mastered shows a star, not a number.
    public var badge: Int? {
        switch self {
        case .recognition: return 1
        case .recall:      return 2
        case .fluency:     return 3
        case .mastered:    return nil
        }
    }

    public var isOpenResponse: Bool { self == .recall || self == .fluency }
}

/// The four colour-coded states shown on the parent dashboard mastery map (§8).
public enum FactDisplayState: Int, Codable, Sendable {
    case notStarted = 0
    case learning   = 1   // recognition or recall
    case fluent     = 2   // fluency stage
    case mastered   = 3

    public static func from(introduced: Bool, stage: MasteryStage) -> FactDisplayState {
        guard introduced else { return .notStarted }
        switch stage {
        case .recognition, .recall: return .learning
        case .fluency:              return .fluent
        case .mastered:             return .mastered
        }
    }
}
