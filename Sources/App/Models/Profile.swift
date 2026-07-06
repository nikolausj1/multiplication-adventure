import Foundation
import SwiftData

/// A learner profile. Multiple profiles are supported; each owns its own facts,
/// sessions, milestones, XP, streak, and settings. Exactly one is active at a time.
@Model
final class Profile {
    var id: UUID
    var name: String
    var avatarSymbol: String       // avatar asset key ("avatar3") or legacy SF Symbol name
    var totalXP: Int
    var createdAt: Date
    var isActive: Bool

    /// First-run state: false until the kid finishes onboarding (name/grade/avatar).
    var onboarded: Bool = false
    /// The grade he's going into ("Pre-K", "K", "1"…"5") — info only.
    var grade: String = ""

    // Streak bookkeeping (§8).
    var lastPracticeDate: Date?
    var streakDays: Int

    // Settings.
    var timingModeRaw: String      // "gentle" | "speed"
    var soundOn: Bool
    var speedRoundUnlocked: Bool
    var bestSpeedAvg: Double = 0   // best (lowest) median response time in a Speed Round; 0 = none yet

    /// Bitmask of worlds whose boss challenge has been beaten. A world *clears* by
    /// beating its boss (not merely by reaching full fluency), so this is explicit state.
    var clearedWorldsMask: Int = 0

    /// Total daily-quest stars earned. Stars are SESSION trophies (a completed
    /// ~10-minute quest), decoupled from fluency counts: 5 stars fill a world's
    /// sockets, its boss unlocks, beating the boss opens the next world.
    var questStars: Int = 0

    /// Bitmask of worlds whose dramatic title reveal has played (first entry).
    var seenWorldIntrosMask: Int = 0

    /// Longest in-session correct streak ever reached (a chase-able trophy stat).
    var bestStreak: Int = 0
    /// Lifetime count of speed bonuses earned (fast correct answers).
    var speedBonusCount: Int = 0

    /// Paused daily quest (X = pause, not quit, for the rest of the day):
    /// re-entering the world resumes the clock, meter, and novelty budget.
    /// Expires at midnight — tomorrow is always a fresh quest.
    var pausedQuestDate: Date? = nil
    var pausedQuestElapsed: Double = 0
    var pausedQuestMeter: Double = 0
    var pausedQuestNewCount: Int = 0

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

    var clearedWorlds: Set<Int> {
        Set((0..<WorldCatalog.count).filter { clearedWorldsMask & (1 << $0) != 0 })
    }

    func markWorldCleared(_ index: Int) { clearedWorldsMask |= (1 << index) }

    func hasSeenWorldIntro(_ index: Int) -> Bool { seenWorldIntrosMask & (1 << index) != 0 }
    func markWorldIntroSeen(_ index: Int) { seenWorldIntrosMask |= (1 << index) }

    /// The adventure's current world: one past the last beaten boss.
    var currentWorldIndex: Int { min(clearedWorlds.count, WorldCatalog.count - 1) }

    /// Stars showing in the current world's sockets. Caps at the per-world total
    /// until the boss falls, so a world never holds more stars than sockets.
    var starsInCurrentWorld: Int {
        let per = WorldCatalog.starsPerWorld
        return max(0, min(per, questStars - per * clearedWorlds.count))
    }

    /// Award the day's quest star. Returns the 0-based socket it fills, or nil
    /// when the current world is full (boss pending — fight it for more sockets!).
    func awardQuestStar() -> Int? {
        guard starsInCurrentWorld < WorldCatalog.starsPerWorld else { return nil }
        questStars += 1
        return starsInCurrentWorld - 1
    }

    /// Records practice on `date` and returns the new streak length. One missed day
    /// is forgiven (summer grace); two or more in a row resets to 1. Progress itself
    /// is never destroyed (§3, no punishment).
    @discardableResult
    func registerPractice(on date: Date, calendar: Calendar = .current) -> Int {
        defer { lastPracticeDate = date }
        guard let last = lastPracticeDate else { streakDays = 1; return streakDays }
        if calendar.isDate(date, inSameDayAs: last) { return streakDays }
        let dayDelta = calendar.dateComponents([.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: date)).day ?? 0
        streakDays = dayDelta <= 2 ? streakDays + 1 : 1
        return streakDays
    }
}

enum TimingMode: String, Codable {
    case gentle
    case speed
}
