import Foundation
import SwiftData

/// An earned milestone (§9, §11). The app surfaces an "earned" marker; the parent
/// delivers the real-world reward offline and marks it fulfilled.
@Model
final class MilestoneRecord {
    var kindLabel: String      // e.g. "Table ×7", "Rank: Builder", "50%", "7-day streak"
    var detail: String
    var tierRaw: Int
    var earnedDate: Date
    var fulfilled: Bool        // parent delivered the real-world reward

    init(kindLabel: String, detail: String, tier: CelebrationTier, earnedDate: Date = .now) {
        self.kindLabel = kindLabel
        self.detail = detail
        self.tierRaw = tier.rawValue
        self.earnedDate = earnedDate
        self.fulfilled = false
    }

    var tier: CelebrationTier { CelebrationTier(rawValue: tierRaw) ?? .t1 }
}
