import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let speedRound: Bool

    @State private var vm: SessionViewModel?

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            if let vm {
                if vm.stage == .finished {
                    WrapView(vm: vm) { dismiss() }
                        .transition(.opacity)
                } else {
                    active(vm)
                }
                if let celebration = vm.pendingCelebration {
                    CelebrationOverlay(celebration: celebration) {
                        vm.pendingCelebration = nil
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            } else {
                ProgressView()
            }
        }
        .animation(Theme.Motion.snappy, value: vm?.stage)
        .onAppear {
            if vm == nil {
                vm = SessionViewModel(service: LearningService(context: context),
                                      speedRound: speedRound)
            }
        }
    }

    @ViewBuilder
    private func active(_ vm: SessionViewModel) -> some View {
        VStack(spacing: 0) {
            topBar(vm)
            Spacer(minLength: 0)
            if let q = vm.current {
                QuestionContainer(vm: vm, question: q)
                    .id(vm.index)                       // fresh state per question
                    .frame(maxWidth: 640)
                    .padding(Theme.Metric.pad)
            }
            Spacer(minLength: 0)
        }
    }

    private func topBar(_ vm: SessionViewModel) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button { vm.stop() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28)).foregroundStyle(Theme.Color.inkSoft)
                }
                Spacer()
                Text(vm.movementLabel.uppercased())
                    .font(Theme.Font.label(13)).tracking(1.5)
                    .foregroundStyle(Theme.Color.inkSoft)
                Spacer()
                Label("\(vm.xpEarned)", systemImage: "star.fill")
                    .font(Theme.Font.number(17)).foregroundStyle(Theme.Color.accent)
            }
            ProgressView(value: vm.progress).tint(Theme.Color.primary)
        }
        .padding(.horizontal, Theme.Metric.pad).padding(.top, 12)
    }
}

/// Picks the question format and bridges feedback/advance back to the view-model.
private struct QuestionContainer: View {
    let vm: SessionViewModel
    let question: PlannedQuestion

    var body: some View {
        VStack(spacing: 32) {
            if question.format == .recognition {
                MultipleChoiceView(
                    question: question,
                    showFeedback: vm.stage == .feedback,
                    selected: vm.lastSelected,
                    onSelect: { vm.answer($0) })
            } else {
                OpenResponseView(
                    question: question,
                    timed: vm.showTimer && question.timed,
                    showFeedback: vm.stage == .feedback,
                    lastCorrect: vm.lastCorrect,
                    onSubmit: { vm.answer($0) })
            }

            if vm.stage == .feedback {
                FeedbackBar(correct: vm.lastCorrect,
                            correctAnswer: question.prompt.answer,
                            xp: vm.lastXP,
                            mastered: vm.justMastered) { vm.next() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { vm.beginQuestion() }
        .animation(Theme.Motion.snappy, value: vm.stage)
    }
}
