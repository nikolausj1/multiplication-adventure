import SwiftUI

/// Neutral-soft feedback row + Continue. No "wrong" framing; a miss simply notes the
/// answer (already revealed) and moves on (§3, no punishment).
struct FeedbackBar: View {
    let correct: Bool
    let correctAnswer: Int
    let xp: Int
    let mastered: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.circle.fill" : "lightbulb.fill")
                    .foregroundStyle(correct ? Theme.Color.correct : Theme.Color.accent)
                    .font(.system(size: 22))
                Text(correct ? message : "Now you know it")
                    .font(Theme.Font.body()).foregroundStyle(Theme.Color.ink)
                if xp > 0 {
                    Text("+\(xp)").font(Theme.Font.number(18)).foregroundStyle(Theme.Color.accent)
                }
            }
            if mastered {
                Label("Fact mastered!", systemImage: "star.fill")
                    .font(Theme.Font.label()).foregroundStyle(Theme.Color.correct)
            }
            Button(action: onContinue) {
                Text("Continue").font(Theme.Font.display(20))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent).tint(Theme.Color.primary)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 420)
        .cardSurface()
    }

    private var message: String {
        switch xp {
        case 18...: return "Lightning fast!"
        case 12...: return "Great!"
        default:    return "Nice!"
        }
    }
}
