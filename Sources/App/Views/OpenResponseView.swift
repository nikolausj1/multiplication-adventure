import SwiftUI

/// Recall & Fluency stages (§4.2): open response on a calculator-style pad. Explicit
/// Enter (handles 1–3 digit answers cleanly); the timer, when shown, counts up.
struct OpenResponseView: View {
    // Compact height = iPhone landscape. The screen is wide but short, so the
    // prompt/entry move to the LEFT of the pad instead of stacking above it —
    // that keeps the number pad tall and the keys big.
    @Environment(\.verticalSizeClass) private var vSize
    let question: PlannedQuestion
    let timed: Bool
    let showFeedback: Bool
    let lastCorrect: Bool
    let onSubmit: (Int) -> Void

    @State private var entry = ""
    @State private var start = Date.now
    @State private var frozenElapsed: Double?   // stops the clock at the moment of answer

    private var answer: Int { question.prompt.answer }
    private var compact: Bool { vSize == .compact }

    var body: some View {
        Group {
            if compact {
                // Two columns: question on the left, pad on the right.
                HStack(spacing: 28) {
                    VStack(spacing: 12) {
                        timerView
                        PromptText(question.displayText)
                        entryField
                    }
                    .frame(maxWidth: .infinity)
                    pad
                }
            } else {
                VStack(spacing: 28) {
                    timerView
                    PromptText(question.displayText)
                    entryField
                    pad
                }
            }
        }
        .onAppear { start = .now }
    }

    @ViewBuilder private var timerView: some View {
        if timed {
            if let frozenElapsed {
                timerText(frozenElapsed)
            } else {
                TimelineView(.periodic(from: start, by: 0.1)) { ctx in
                    timerText(ctx.date.timeIntervalSince(start))
                }
            }
        }
    }

    private var pad: some View {
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

    /// Fixed-size entry plate: feedback recolors the digits in place (the true
    /// equation appears in the feedback pill), so nothing on screen moves.
    private var entryField: some View {
        Text(entry.isEmpty ? " " : entry)
            .font(Theme.Font.number(compact ? 34 : 48))
            .foregroundStyle(showFeedback ? (lastCorrect ? Theme.Color.correct : .white.opacity(0.45))
                                          : .white)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .frame(minWidth: compact ? 130 : 170, minHeight: compact ? 46 : 70)
            .padding(.horizontal, compact ? 18 : 24)
            .darkPlate()
    }

    private func timerText(_ elapsed: Double) -> some View {
        Label(String(format: "%.1fs", max(0, elapsed)), systemImage: "stopwatch.fill")
            .font(Theme.Font.number(18)).foregroundStyle(Theme.Color.accent)
            .monospacedDigit()
            .padding(.horizontal, 14).padding(.vertical, 7)
            .darkPlate(corner: 20)
    }

    private func submit() {
        guard !entry.isEmpty, let value = Int(entry), !showFeedback else { return }
        frozenElapsed = Date.now.timeIntervalSince(start)
        onSubmit(value)
    }
}
