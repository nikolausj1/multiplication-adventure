import Foundation
import SwiftData

/// Persistent per-fact learning state (§11). Bridges to the pure-engine `FactSnapshot`
/// so all logic stays in the testable, Foundation-only engine.
@Model
final class Fact {
    @Attribute(.unique) var key: String
    var a: Int
    var b: Int

    var introduced: Bool
    var stageRaw: Int
    var box: Int
    var dueDate: Date

    var recognitionStreak: Int
    var recallCorrect: Int
    var fluencyFastDays: [Int]
    var fluencyFastCount: Int

    var totalAttempts: Int
    var totalCorrect: Int
    var recentTimes: [Double]
    var averageTime: Double
    var lastSeen: Date?
    var lastErrorDate: Date?
    var masteredDate: Date?
    var lapseCount: Int

    init(_ id: FactID) {
        self.key = id.key
        self.a = id.a
        self.b = id.b
        self.introduced = false
        self.stageRaw = MasteryStage.recognition.rawValue
        self.box = 0
        self.dueDate = .distantPast
        self.recognitionStreak = 0
        self.recallCorrect = 0
        self.fluencyFastDays = []
        self.fluencyFastCount = 0
        self.totalAttempts = 0
        self.totalCorrect = 0
        self.recentTimes = []
        self.averageTime = 0
        self.lapseCount = 0
    }

    var id: FactID { FactID(a, b) }
    var stage: MasteryStage { MasteryStage(rawValue: stageRaw) ?? .recognition }

    var snapshot: FactSnapshot {
        FactSnapshot(
            id: id,
            introduced: introduced,
            stage: stage,
            box: box,
            dueDate: dueDate,
            recognitionStreak: recognitionStreak,
            recallCorrect: recallCorrect,
            fluencyFastDays: Set(fluencyFastDays),
            fluencyFastCount: fluencyFastCount,
            totalAttempts: totalAttempts,
            totalCorrect: totalCorrect,
            recentTimes: recentTimes,
            averageTime: averageTime,
            lastSeen: lastSeen,
            lastErrorDate: lastErrorDate,
            masteredDate: masteredDate,
            lapseCount: lapseCount
        )
    }

    func apply(_ s: FactSnapshot) {
        introduced = s.introduced
        stageRaw = s.stage.rawValue
        box = s.box
        dueDate = s.dueDate
        recognitionStreak = s.recognitionStreak
        recallCorrect = s.recallCorrect
        fluencyFastDays = Array(s.fluencyFastDays)
        fluencyFastCount = s.fluencyFastCount
        totalAttempts = s.totalAttempts
        totalCorrect = s.totalCorrect
        recentTimes = s.recentTimes
        averageTime = s.averageTime
        lastSeen = s.lastSeen
        lastErrorDate = s.lastErrorDate
        masteredDate = s.masteredDate
        lapseCount = s.lapseCount
    }
}
