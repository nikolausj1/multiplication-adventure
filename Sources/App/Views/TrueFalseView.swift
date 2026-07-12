import SwiftUI

/// Verification review ("7 × 8 = 54 — true or false?"): the equation sits on the
/// world plaque and the child taps one of two big keys. Feedback lands in place —
/// the correct key turns green and glows, the other steps back — nothing moves.
struct TrueFalseView: View {
    @Environment(\.verticalSizeClass) private var vSize
    let question: PlannedQuestion
    let showFeedback: Bool
    let selected: Int?               // 1 = True, 0 = False, nil = unanswered
    let onSelect: (Int) -> Void

    /// 1 if the shown equation is actually true.
    private var trueIsCorrect: Bool { question.expectedAnswer == 1 }
    private var compact: Bool { vSize == .compact }

    var body: some View {
        VStack(spacing: compact ? 12 : 26) {
            PromptText(question.displayText)
            // On the short iPhone screen the label is dropped to save height —
            // the green ✓ / red ✗ keys read as true/false on their own.
            if !compact {
                Text("TRUE or FALSE?")
                    .font(Theme.Font.label(16)).tracking(3)
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
            HStack(spacing: compact ? 14 : 18) {
                key(value: 1, title: "TRUE", icon: "checkmark",
                    tint: Theme.Color.correct)
                key(value: 0, title: "FALSE", icon: "xmark",
                    tint: Color(red: 0.88, green: 0.28, blue: 0.24))
            }
            .frame(maxWidth: 560)
        }
        .animation(Theme.Motion.snappy, value: showFeedback)
    }

    private func key(value: Int, title: String, icon: String, tint: Color) -> some View {
        let isCorrectKey = (value == 1) == trueIsCorrect
        let isPicked = value == selected
        let dimmed = showFeedback && !isCorrectKey
        // On feedback the correct key always lights green; the wrong-but-picked
        // key greys so a miss reads as "here's the right one", never a buzzer.
        let base: Color = showFeedback ? (isCorrectKey ? Theme.Color.correct
                                          : (isPicked ? Color(white: 0.45) : tint))
                                       : tint
        return Button { if !showFeedback { onSelect(value) } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 34, weight: .heavy))
                Text(title).font(Theme.Font.display(26))
            }
            .frame(maxWidth: .infinity, minHeight: 118)
        }
        .buttonStyle(ChunkyKeyStyle(base: base, deep: base.shaded(by: -0.35), corner: 22))
        .disabled(showFeedback)
        .saturation(dimmed ? 0.45 : 1)
        .opacity(dimmed ? (isPicked ? 0.8 : 0.55) : 1)
        .scaleEffect(showFeedback && isCorrectKey ? 1.05 : 1)
        .shadow(color: showFeedback && isCorrectKey ? Theme.Color.correct.opacity(0.75) : .clear,
                radius: 14)
        .overlay {
            if showFeedback && isCorrectKey {
                ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 10)
                    .frame(width: 170, height: 170)
            }
        }
        .accessibilityLabel(title)
    }
}
