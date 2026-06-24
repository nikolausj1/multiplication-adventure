import Foundation
import SwiftData

/// The single child profile (§11). Holds identity, the XP total, streak bookkeeping,
/// and settings. One row in v1.
@Model
final class Profile {
    var name: String
    var avatarSymbol: String       // SF Symbol name (static avatar in v1)
    var totalXP: Int
    var createdAt: Date

    // Streak bookkeeping (§8).
    var lastPracticeDate: Date?
    var streakDays: Int

    // Settings (§11).
    var timingModeRaw: String      // "gentle" | "speed"
    var soundOn: Bool
    var speedRoundUnlocked: Bool

    init(name: String = "Champion", avatarSymbol: String = "bolt.circle.fill") {
        self.name = name
        self.avatarSymbol = avatarSymbol
        self.totalXP = 0
        self.createdAt = .now
        self.lastPracticeDate = nil
        self.streakDays = 0
        self.timingModeRaw = TimingMode.gentle.rawValue
        self.soundOn = true
        self.speedRoundUnlocked = false
    }

    var timingMode: TimingMode {
        get { TimingMode(rawValue: timingModeRaw) ?? .gentle }
        set { timingModeRaw = newValue.rawValue }
    }

    /// Records practice on `date` and returns the new streak length. Missing a day
    /// resets the streak to 1 but never destroys progress (§3, no punishment).
    @discardableResult
    func registerPractice(on date: Date, calendar: Calendar = .current) -> Int {
        defer { lastPracticeDate = date }
        guard let last = lastPracticeDate else { streakDays = 1; return streakDays }
        if calendar.isDate(date, inSameDayAs: last) { return streakDays }   // already counted today
        let dayDelta = calendar.dateComponents([.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: date)).day ?? 0
        streakDays = dayDelta == 1 ? streakDays + 1 : 1
        return streakDays
    }
}

enum TimingMode: String, Codable {
    case gentle   // no visible timer; speed measured silently
    case speed    // Speed Round with visible count-up timer
}
