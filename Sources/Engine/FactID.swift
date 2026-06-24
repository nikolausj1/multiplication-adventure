import Foundation

/// A multiplication fact, stored canonically (a <= b) so that 7×8 and 8×7 are
/// the same underlying fact. Prompts are presented in both orders.
public struct FactID: Hashable, Codable, Sendable, Comparable {
    public let a: Int   // smaller factor
    public let b: Int   // larger factor

    public init(_ x: Int, _ y: Int) {
        if x <= y { self.a = x; self.b = y } else { self.a = y; self.b = x }
    }

    public var product: Int { a * b }

    /// Stable key, e.g. "7x8".
    public var key: String { "\(a)x\(b)" }

    public static func < (lhs: FactID, rhs: FactID) -> Bool {
        lhs.b != rhs.b ? lhs.b < rhs.b : lhs.a < rhs.a
    }
}

/// A concrete prompt: the same fact may be shown as a×b or b×a.
public struct OrientedPrompt: Hashable, Sendable {
    public let fact: FactID
    public let firstFactor: Int
    public let secondFactor: Int

    public init(fact: FactID, swapped: Bool) {
        self.fact = fact
        if swapped {
            self.firstFactor = fact.b
            self.secondFactor = fact.a
        } else {
            self.firstFactor = fact.a
            self.secondFactor = fact.b
        }
    }

    public var answer: Int { firstFactor * secondFactor }
    public var text: String { "\(firstFactor) × \(secondFactor)" }
}
