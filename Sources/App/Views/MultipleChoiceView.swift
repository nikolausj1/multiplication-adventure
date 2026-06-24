import SwiftUI

/// Recognition stage (§4.2): four plausible options. Neutral-soft feedback — the
/// correct option lifts, a wrong pick dims; never a red buzzer.
struct MultipleChoiceView: View {
    let question: PlannedQuestion
    let showFeedback: Bool
    let selected: Int?
    let onSelect: (Int) -> Void

    private var answer: Int { question.prompt.answer }
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 36) {
            PromptText(question.prompt)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(question.options ?? [], id: \.self) { option in
                    Button { if !showFeedback { onSelect(option) } } label: {
                        Text("\(option)")
                            .font(Theme.Font.number(40))
                            .frame(maxWidth: .infinity).padding(.vertical, 28)
                            .foregroundStyle(foreground(option))
                            .background(background(option))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous)
                                    .strokeBorder(Theme.Color.primary.opacity(showFeedback ? 0 : 0.12), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PopButtonStyle())
                    .disabled(showFeedback)
                    .scaleEffect(showFeedback && option == answer ? 1.04 : 1)
                    .accessibilityLabel("\(option)")
                }
            }
        }
        .animation(Theme.Motion.snappy, value: showFeedback)
    }

    private func background(_ option: Int) -> Color {
        guard showFeedback else { return Theme.Color.surface }
        if option == answer { return Theme.Color.correct.opacity(0.18) }
        if option == selected { return Theme.Color.gentle.opacity(0.18) }
        return Theme.Color.surface.opacity(0.5)
    }
    private func foreground(_ option: Int) -> Color {
        guard showFeedback else { return Theme.Color.ink }
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
            .font(Theme.Font.display(64))
            .foregroundStyle(Theme.Color.ink)
            .minimumScaleFactor(0.6).lineLimit(1)
    }
}
