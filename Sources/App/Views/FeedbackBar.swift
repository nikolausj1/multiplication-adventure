import SwiftUI

/// Answer feedback as one compact pill that fades into a permanently reserved slot,
/// so the question and buttons never move. Neutral-soft: a miss shows the true
/// equation and a Continue key — never a buzzer or red (§3).
struct FeedbackBar: View {
    @Environment(\.worldTheme) private var theme
    let correct: Bool
    let equation: String           // e.g. "7 × 8 = 56", shown on a miss
    let xp: Int
    var hotStreak: Int = 0         // >0 when this answer hit a fast-streak milestone
    let mastered: Bool
    var showsContinue: Bool = true
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: correct ? "checkmark.circle.fill" : "lightbulb.fill")
                .foregroundStyle(correct ? Theme.Color.correct : Theme.Color.accent)
                .font(.system(size: 26))
                .background {
                    if correct {
                        // A streak milestone earns a bigger, warmer burst.
                        ParticleBurst(kind: .stars,
                                      colors: hotStreak > 0
                                        ? [Theme.Color.accent, Color(red: 1, green: 0.5, blue: 0.15), .white]
                                        : [Theme.Color.accent, .white],
                                      count: hotStreak > 0 ? 18 : 8)
                            .frame(width: 120, height: 120)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(correct ? message : equation)
                    .font(correct ? Theme.Font.body(19) : Theme.Font.number(24))
                    .foregroundStyle(.white)
                if mastered {
                    Label("Fact mastered!", systemImage: "star.fill")
                        .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.accent)
                } else if hotStreak > 0 {
                    Label(streakText, systemImage: "flame.fill")
                        .font(Theme.Font.label(14)).foregroundStyle(Color(red: 1, green: 0.5, blue: 0.15))
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
        switch xp {
        case 18...: return "Lightning fast!"
        case 12...: return "Great!"
        default:    return "Nice!"
        }
    }

    private var streakText: String {
        switch hotStreak {
        case 15...: return "Unstoppable! \(hotStreak) in a row!"
        case 10...: return "On fire! \(hotStreak) in a row!"
        default:    return "\(hotStreak) in a row!"
        }
    }
}
