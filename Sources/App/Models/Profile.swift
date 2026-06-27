import Foundation
import SwiftData

/// A learner profile. Multiple profiles are supported; each owns its own facts,
/// sessions, milestones, XP, streak, and settings. Exactly one is active at a time.
@Model
final class Profile {
    var id: UUID
    var name: String
    var avatarSymbol: String       // SF Symbol name (static avatar in v1)
    var totalXP: Int
    var createdAt: Date
    var isActive: Bool

    // Streak bookkeeping (§8).
    var lastPracticeDate: Date?
    var streakDays: Int

    // Settings.
    var timingModeRaw: String      // "gentle" | "speed"
    var soundOn: Bool
    var speedRoundUnlocked: Bool
    var bestSpeedAvg: Double = 0   // best (lowest) median response time in a Speed Round; 0 = none yet

    // Per-profile data (cascade so deleting a profile cleans everything up).
    @Relationship(deleteRule: .cascade, inverse: \Fact.profile) var facts: [Fact] = []
    @Relationship(deleteRule: .cascade, inverse: \SessionRecord.profile) var sessions: [SessionRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \MilestoneRecord.profile) var milestones: [MilestoneRecord] = []

    init(name: String = "Player 1", avatarSymbol: String = "figure.hiking", isActive: Bool = true) {
        self.id = UUID()
        self.name = name
        self.avatarSymbol = avatarSymbol
        self.totalXP = 0
        self.createdAt = .now
        self.isActive = isActive
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

    var masteredCount: Int { facts.filter { $0.stage == .mastered }.count }

    /// Records practice on `date` and returns the new streak length. Missing a day
    /// resets the streak to 1 but never destroys progress (§3, no punishment).
    @discardableResult
    func registerPractice(on date: Date, calendar: Calendar = .current) -> Int {
        defer { lastPracticeDate = date }
        guard let last = lastPracticeDate else { streakDays = 1; return streakDays }
        if calendar.isDate(date, inSameDayAs: last) { return streakDays }
        let dayDelta = calendar.dateComponents([.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: date)).day ?? 0
        streakDays = dayDelta == 1 ? streakDays + 1 : 1
        return streakDays
    }
}

enum TimingMode: String, Codable {
    case gentle
    case speed
}
