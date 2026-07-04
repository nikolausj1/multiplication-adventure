import SwiftUI

/// Recognition stage (§4.2): four options on chunky world-tinted keys — one button
/// family per level, numbers dead-center. Feedback happens in place: the correct key
/// turns green and glows, others step back. Nothing on screen moves.
struct MultipleChoiceView: View {
    @Environment(\.worldTheme) private var theme
    let question: PlannedQuestion
    let showFeedback: Bool
    let selected: Int?
    let onSelect: (Int) -> Void

    private var answer: Int { question.prompt.answer }
    private let columns = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]

    var body: some View {
        VStack(spacing: 26) {
            PromptText(question.prompt)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(question.options ?? [], id: \.self) { option in
                    optionButton(option)
                }
            }
            .frame(maxWidth: 560)
        }
        .animation(Theme.Motion.snappy, value: showFeedback)
    }

    private func optionButton(_ option: Int) -> some View {
        let isAnswer = option == answer
        let isPicked = option == selected
        let dimmed = showFeedback && !isAnswer
        return Button { if !showFeedback { onSelect(option) } } label: {
            Text("\(option)")
                .font(Theme.Font.number(38))
                .frame(maxWidth: .infinity, minHeight: 92)
        }
        .buttonStyle(ChunkyKeyStyle(base: keyBase(isAnswer: isAnswer, isPicked: isPicked),
                                    deep: keyDeep(isAnswer: isAnswer),
                                    corner: 20))
        .disabled(showFeedback)
        .saturation(dimmed ? 0.45 : 1)
        .opacity(dimmed ? (isPicked ? 0.8 : 0.55) : 1)
        .scaleEffect(showFeedback && isAnswer ? 1.05 : 1)
        .shadow(color: showFeedback && isAnswer ? Theme.Color.correct.opacity(0.75) : .clear,
                radius: 14)
        .overlay {
            if showFeedback && isAnswer {
                ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 10)
                    .frame(width: 170, height: 170)
            }
        }
        .accessibilityLabel("\(option)")
    }

    private func keyBase(isAnswer: Bool, isPicked: Bool) -> Color {
        guard showFeedback else { return theme.primary }
        if isAnswer { return Theme.Color.correct }
        if isPicked { return Color(white: 0.45) }
        return theme.primary
    }

    private func keyDeep(isAnswer: Bool) -> Color {
        showFeedback && isAnswer ? Theme.Color.correct.shaded(by: -0.35) : theme.deep
    }
}

/// The hero numeral prompt on the world's ornate plaque (the button art, reborn) —
/// dark-glass fallback for any world without plaque art. Readability always wins:
/// a soft dark blob sits behind the numeral over the busy frame centers.
struct PromptText: View {
    @Environment(\.worldTheme) private var theme
    let prompt: OrientedPrompt
    init(_ p: OrientedPrompt) { prompt = p }

    var body: some View {
        if Art.exists(theme.buttonImage) {
            ZStack {
                Image(theme.buttonImage)
                    .resizable().scaledToFit()
                    .frame(height: 150)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
                numeral
                    .background(
                        Ellipse().fill(Color.black.opacity(0.38))
                            .blur(radius: 16)
                            .padding(.horizontal, -30).padding(.vertical, -10))
            }
        } else {
            numeral
                .padding(.horizontal, 36).padding(.vertical, 12)
                .darkPlate()
        }
    }

    private var numeral: some View {
        Text(prompt.text)
            .font(Theme.Font.display(58))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.55), radius: 3, y: 2)
            .minimumScaleFactor(0.6).lineLimit(1)
    }
}
