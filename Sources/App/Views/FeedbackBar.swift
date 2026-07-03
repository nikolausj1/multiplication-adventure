import SwiftUI

/// Neutral-soft feedback row on a dark plate over the world art. No "wrong" framing;
/// a miss simply notes the answer (already revealed) and moves on (§3, no punishment).
struct FeedbackBar: View {
    @Environment(\.worldTheme) private var theme
    let correct: Bool
    let correctAnswer: Int
    let xp: Int
    let mastered: Bool
    var showsContinue: Bool = true
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.circle.fill" : "lightbulb.fill")
                    .foregroundStyle(correct ? Theme.Color.correct : Theme.Color.accent)
                    .font(.system(size: 22))
                    .background {
                        if correct {
                            ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 8)
                                .frame(width: 110, height: 110)
                        }
                    }
                Text(correct ? message : "Now you know it")
                    .font(Theme.Font.body()).foregroundStyle(.white)
                if xp > 0 {
                    Text("+\(xp)").font(Theme.Font.number(18)).foregroundStyle(Theme.Color.accent)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .darkPlate(corner: 18)
            if mastered {
                Label("Fact mastered!", systemImage: "star.fill")
                    .font(Theme.Font.label()).foregroundStyle(Theme.Color.correct)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .darkPlate(corner: 16)
            }
            if showsContinue {
                Button(action: onContinue) {
                    Text("Continue").font(Theme.Font.display(20))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .buttonStyle(ChunkyKeyStyle(base: theme.primary, deep: theme.deep,
                                            corner: Theme.Metric.corner))
            }
        }
        .padding(.top, 6)
        .frame(maxWidth: 420)
    }

    private var message: String {
        switch xp {
        case 18...: return "Lightning fast!"
        case 12...: return "Great!"
        default:    return "Nice!"
        }
    }
}
