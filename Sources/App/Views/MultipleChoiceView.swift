import SwiftUI

/// Recognition stage (§4.2): four plausible options on the world's themed buttons.
/// Neutral-soft feedback — the correct option glows green and lifts, a wrong pick
/// dims; the art never disappears mid-answer.
struct MultipleChoiceView: View {
    @Environment(\.worldTheme) private var theme
    let question: PlannedQuestion
    let showFeedback: Bool
    let selected: Int?
    let onSelect: (Int) -> Void

    private var answer: Int { question.prompt.answer }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 24) {
            PromptText(question.prompt)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(question.options ?? [], id: \.self) { option in
                    optionButton(option)
                }
            }
        }
        .animation(Theme.Motion.snappy, value: showFeedback)
    }

    private func optionButton(_ option: Int) -> some View {
        let isAnswer = option == answer
        let isPicked = option == selected
        return Button { if !showFeedback { onSelect(option) } } label: {
            ZStack {
                if Art.exists(theme.buttonImage) {
                    Image(theme.buttonImage).resizable().scaledToFit()   // undistorted skin
                } else {
                    RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous)
                        .fill(LinearGradient(colors: [theme.primary, theme.deep],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Metric.corner)
                            .strokeBorder(theme.accent.opacity(0.8), lineWidth: 3))
                }
                // The number rides a small chip so it reads over any ornate art.
                Text("\(option)")
                    .font(Theme.Font.number(32))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 5)
                    .background(chipColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(chipStroke(isAnswer: isAnswer, isPicked: isPicked), lineWidth: 2))
            }
            .frame(height: 108)
            .contentShape(Rectangle())
        }
        .buttonStyle(PopButtonStyle())
        .disabled(showFeedback)
        // Feedback keeps the art: correct lifts + glows, the rest step back.
        .saturation(showFeedback && !isAnswer ? 0.35 : 1)
        .opacity(showFeedback && !isAnswer ? (isPicked ? 0.75 : 0.45) : 1)
        .scaleEffect(showFeedback && isAnswer ? 1.07 : 1)
        .overlay {
            if showFeedback && isAnswer {
                ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 10)
                    .frame(width: 150, height: 150)
            }
        }
        .shadow(color: showFeedback && isAnswer ? Theme.Color.correct.opacity(0.8) : .clear,
                radius: 12)
        .accessibilityLabel("\(option)")
    }

    private var chipColor: Color { Color.black.opacity(0.42) }

    private func chipStroke(isAnswer: Bool, isPicked: Bool) -> Color {
        guard showFeedback else { return .white.opacity(0.25) }
        if isAnswer { return Theme.Color.correct }
        if isPicked { return Theme.Color.gentle }
        return .white.opacity(0.1)
    }
}

/// The hero numeral prompt on its own dark plate — readable over any world.
struct PromptText: View {
    let prompt: OrientedPrompt
    init(_ p: OrientedPrompt) { prompt = p }
    var body: some View {
        Text(prompt.text)
            .font(Theme.Font.display(58))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
            .minimumScaleFactor(0.6).lineLimit(1)
            .padding(.horizontal, 36).padding(.vertical, 12)
            .darkPlate()
    }
}
