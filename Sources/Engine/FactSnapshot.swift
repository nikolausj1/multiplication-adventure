import Foundation

/// A pure value-type view of a fact's learning state. The SwiftData `Fact` model
/// bridges to/from this so the entire engine stays Foundation-only and testable.
public struct FactSnapshot: Sendable, Equatable {
    public let id: FactID

    public var introduced: Bool
    public var stage: MasteryStage
    public var box: Int                 // Leitner box, 0...6
    public var dueDate: Date

    // Per-stage progress counters (drive promotion, §4.3).
    public var recognitionStreak: Int   // consecutive correct MC
    public var recallCorrect: Int       // correct open responses in Recall (reset on error)
    public var fluencyFastDays: Set<Int>// distinct calendar days with a fast-correct in Fluency
    public var fluencyFastCount: Int     // total fast-correct in Fluency

    // Telemetry (§4.5).
    public var totalAttempts: Int
    public var totalCorrect: Int
    public var recentTimes: [Double]    // last N response times (seconds)
    public var averageTime: Double
    public var lastSeen: Date?
    public var lastErrorDate: Date?
    public var masteredDate: Date?
    public var lapseCount: Int

    public init(
        id: FactID,
        introduced: Bool = false,
        stage: MasteryStage = .recognition,
        box: Int = 0,
        dueDate: Date = .distantPast,
        recognitionStreak: Int = 0,
        recallCorrect: Int = 0,
        fluencyFastDays: Set<Int> = [],
        fluencyFastCount: Int = 0,
        totalAttempts: Int = 0,
        totalCorrect: Int = 0,
        recentTimes: [Double] = [],
        averageTime: Double = 0,
        lastSeen: Date? = nil,
        lastErrorDate: Date? = nil,
        masteredDate: Date? = nil,
        lapseCount: Int = 0
    ) {
        self.id = id
        self.introduced = introduced
        self.stage = stage
        self.box = box
        self.dueDate = dueDate
        self.recognitionStreak = recognitionStreak
        self.recallCorrect = recallCorrect
        self.fluencyFastDays = fluencyFastDays
        self.fluencyFastCount = fluencyFastCount
        self.totalAttempts = totalAttempts
        self.totalCorrect = totalCorrect
        self.recentTimes = recentTimes
        self.averageTime = averageTime
        self.lastSeen = lastSeen
        self.lastErrorDate = lastErrorDate
        self.masteredDate = masteredDate
        self.lapseCount = lapseCount
    }

    public var displayState: FactDisplayState {
        FactDisplayState.from(introduced: introduced, stage: stage)
    }

    public var accuracy: Double {
        totalAttempts == 0 ? 0 : Double(totalCorrect) / Double(totalAttempts)
    }

    public func isDue(asOf now: Date) -> Bool { dueDate <= now }
}

/// Helpers for collapsing a `Date` to an integer calendar day (used for the
/// cross-day mastery requirement and streaks). Uses the current calendar.
public enum DayStamp {
    public static func of(_ date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        // Pack y/m/d into a single comparable integer.
        return (comps.year ?? 0) * 10000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
    }
}
