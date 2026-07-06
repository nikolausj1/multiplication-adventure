import SwiftUI

/// Answer feedback as one compact pill that fades into a permanently reserved slot,
/// so the question and buttons never move. Neutral-soft: a miss shows the true
/// equation and a Continue key — never a buzzer or red (§3).
struct FeedbackBar: View {
    @Environment(\.worldTheme) private var theme
    let correct: Bool
    let equation: String           // e.g. "7 × 8 = 56", shown on a miss
    let xp: Int
    var hotStreak: Int = 0         // >0 when this answer hit a streak milestone
    var wasFast: Bool = false      // this answer also beat the speed bar
    let mastered: Bool
    var showsContinue: Bool = true
    let onContinue: () -> Void

    private static let speedColor = Color(red: 0.2, green: 0.7, blue: 1.0)
    private static let flameColor = Color(red: 1, green: 0.5, blue: 0.15)

    var body: some View {
        HStack(spacing: 14) {
            // The lead icon reads the moment: a lightning bolt when it was fast,
            // otherwise a plain check. A miss shows the hint bulb.
            Image(systemName: !correct ? "lightbulb.fill" : (wasFast ? "bolt.fill" : "checkmark.circle.fill"))
                .foregroundStyle(!correct ? Theme.Color.accent : (wasFast ? Self.speedColor : Theme.Color.correct))
                .font(.system(size: 26))
                .background {
                    if correct {
                        // Streak milestone → big warm burst; a fast answer → a
                        // cool blue spark; otherwise the small default.
                        ParticleBurst(kind: .stars,
                                      colors: hotStreak > 0
                                        ? [Theme.Color.accent, Self.flameColor, .white]
                                        : (wasFast ? [Self.speedColor, .white] : [Theme.Color.accent, .white]),
                                      count: hotStreak > 0 ? 18 : (wasFast ? 14 : 8))
                            .frame(width: 120, height: 120)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(correct ? message : equation)
                    .font(correct ? Theme.Font.body(19) : Theme.Font.number(24))
                    .foregroundStyle(.white)
                // Sub-badges stack: speed (bolt) and/or streak (flame), each
                // self-explaining so the kid learns which reward is which.
                HStack(spacing: 10) {
                    if mastered {
                        Label("Fact mastered!", systemImage: "star.fill")
                            .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.accent)
                    } else {
                        if wasFast {
                            Label("Speed bonus!", systemImage: "bolt.fill")
                                .font(Theme.Font.label(14)).foregroundStyle(Self.speedColor)
                        }
                        if hotStreak > 0 {
                            Label(streakText, systemImage: "flame.fill")
                                .font(Theme.Font.label(14)).foregroundStyle(Self.flameColor)
                        }
                    }
                }
            }
            if correct && xp > 0 {
                Text("+\(xp)").font(Theme.Font.number(20)).foregroundStyle(Theme.Color.accent)
            }
            if showsContinue {
                Button(action: onContinue) {
                    Text("Continue").font(Theme.Font.label(17))
                        .padding(.horizontal, 22).padding(.vertical, 11)
                }
                .buttonStyle(ChunkyKeyStyle(base: theme.primary, deep: theme.deep, corner: 14))
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 13)
        .darkPlate(corner: 26)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder((correct ? Theme.Color.correct : Theme.Color.accent).opacity(0.55),
                          lineWidth: 1.5))
    }

    private var message: String {
        if wasFast { return "Lightning fast!" }
        return xp >= 12 ? "Great!" : "Nice!"
    }

    private var streakText: String {
        switch hotStreak {
        case 15...: return "Unstoppable! \(hotStreak) in a row!"
        case 10...: return "On fire! \(hotStreak) in a row!"
        default:    return "\(hotStreak) in a row!"
        }
    }
}
