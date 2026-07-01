import SwiftUI

/// Recall & Fluency stages (§4.2): open response on a calculator-style pad. Explicit
/// Enter (handles 1–3 digit answers cleanly); the timer, when shown, counts up.
struct OpenResponseView: View {
    let question: PlannedQuestion
    let timed: Bool
    let showFeedback: Bool
    let lastCorrect: Bool
    let onSubmit: (Int) -> Void

    @State private var entry = ""
    @State private var start = Date.now
    @State private var frozenElapsed: Double?   // stops the clock at the moment of answer

    private var answer: Int { question.prompt.answer }

    var body: some View {
        VStack(spacing: 28) {
            if timed {
                if let frozenElapsed {
                    timerText(frozenElapsed)
                } else {
                    TimelineView(.periodic(from: start, by: 0.1)) { ctx in
                        timerText(ctx.date.timeIntervalSince(start))
                    }
                }
            }

            PromptText(question.prompt)

            entryField

            NumberPadView(
                enterEnabled: !entry.isEmpty && !showFeedback,
                onDigit: { d in
                    guard !showFeedback, entry.count < 3 else { return }
                    entry.append(String(d)); Feedback.fire(.keyTap)
                },
                onDelete: { if !showFeedback { _ = entry.popLast() } },
                onEnter: { submit() })
            .disabled(showFeedback)
            .opacity(showFeedback ? 0.4 : 1)
        }
        .onAppear { start = .now }
    }

    private var entryField: some View {
        HStack(spacing: 12) {
            Text(entry.isEmpty ? " " : entry)
                .font(Theme.Font.number(48))
                .foregroundStyle(showFeedback ? (lastCorrect ? Theme.Color.correct : Theme.Color.inkSoft)
                                              : Theme.Color.ink)
            if showFeedback && !lastCorrect {
                Image(systemName: "arrow.right").foregroundStyle(Theme.Color.inkSoft)
                Text("\(answer)").font(Theme.Font.number(48)).foregroundStyle(Theme.Color.correct)
            }
        }
        .frame(minWidth: 160, minHeight: 70)
        .padding(.horizontal, 24)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.corner, style: .continuous))
    }

    private func timerText(_ elapsed: Double) -> some View {
        Text(String(format: "%.1fs", max(0, elapsed)))
            .font(Theme.Font.number(20)).foregroundStyle(Theme.Color.accent)
            .monospacedDigit()
    }

    private func submit() {
        guard !entry.isEmpty, let value = Int(entry), !showFeedback else { return }
        frozenElapsed = Date.now.timeIntervalSince(start)
        onSubmit(value)
    }
}
