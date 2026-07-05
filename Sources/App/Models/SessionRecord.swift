import Foundation
import SwiftData

/// A completed (or stopped) session (§11). Stores the per-session snapshot that
/// backs the dashboard's accuracy/speed trend over time (the trend-data decision).
@Model
final class SessionRecord {
    var profile: Profile?
    var date: Date
    var questionCount: Int
    var correctCount: Int
    var xpEarned: Int
    var medianResponseTime: Double
    var factsTouched: Int
    /// This session completed the daily quest (streak-calendar flame days).
    var starEarned: Bool = false
    /// Facts that reached Fluency during this session (weekly dashboard stat).
    var fluentGained: Int = 0

    init(date: Date = .now, questionCount: Int = 0, correctCount: Int = 0,
         xpEarned: Int = 0, medianResponseTime: Double = 0, factsTouched: Int = 0) {
        self.date = date
        self.questionCount = questionCount
        self.correctCount = correctCount
        self.xpEarned = xpEarned
        self.medianResponseTime = medianResponseTime
        self.factsTouched = factsTouched
    }

    var accuracy: Double {
        questionCount == 0 ? 0 : Double(correctCount) / Double(questionCount)
    }
}
