import SwiftUI

/// Recognition stage (§4.2): four plausible options on the world's themed buttons.
/// Neutral-soft feedback — the correct option lifts, a wrong pick dims; never a buzzer.
struct MultipleChoiceView: View {
    @Environment(\.worldTheme) private var theme
    let question: PlannedQuestion
    let showFeedback: Bool
    let selected: Int?
    let onSelect: (Int) -> Void

    private var answer: Int { question.prompt.answer }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 22) {
            PromptText(question.prompt).frame(maxWidth: .infinity)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(question.options ?? [], id: \.self) { option in
                    Button { if !showFeedback { onSelect(option) } } label: {
                        ZStack(alignment: .center) {
                            if showFeedback {
                                RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous)
                                    .fill(feedbackFill(option))
                            } else if Art.exists(theme.buttonImage) {
                                Image(theme.buttonImage).resizable().scaledToFit()  // undistorted skin
                            } else {
                                RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous)
                                    .fill(LinearGradient(colors: [theme.primary, theme.deep],
                                                         startPoint: .top, endPoint: .bottom))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Metric.corner)
                                        .strokeBorder(theme.accent.opacity(0.8), lineWidth: 3))
                            }
                            Text("\(option)")
                                .font(Theme.Font.number(34))
                                .foregroundStyle(textColor(option))
                                .shadow(color: .black.opacity(showFeedback ? 0 : 0.55), radius: 3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(height: 104)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PopButtonStyle())
                    .disabled(showFeedback)
                    .scaleEffect(showFeedback && option == answer ? 1.05 : 1)
                    .accessibilityLabel("\(option)")
                }
            }
        }
        .animation(Theme.Motion.snappy, value: showFeedback)
    }

    private func feedbackFill(_ option: Int) -> Color {
        if option == answer { return Theme.Color.correct.opacity(0.22) }
        if option == selected { return Theme.Color.gentle.opacity(0.22) }
        return Theme.Color.surface.opacity(0.6)
    }
    private func textColor(_ option: Int) -> Color {
        guard showFeedback else { return .white }
        if option == answer { return Theme.Color.correct }
        if option == selected { return Theme.Color.inkSoft }
        return Theme.Color.inkSoft.opacity(0.6)
    }
}

/// The hero numeral prompt, shared across stages.
struct PromptText: View {
    let prompt: OrientedPrompt
    init(_ p: OrientedPrompt) { prompt = p }
    var body: some View {
        Text(prompt.text)
            .font(Theme.Font.display(60))
            .foregroundStyle(Theme.Color.ink)
            .minimumScaleFactor(0.6).lineLimit(1)
    }
}
