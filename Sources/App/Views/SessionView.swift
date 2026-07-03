import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var worldIndex: Int = 0
    var speedRound: Bool = false
    var testFormat: MasteryStage? = nil

    @State private var vm: SessionViewModel?
    private var theme: WorldTheme { .forWorld(worldIndex) }

    var body: some View {
        ZStack {
            WorldBackdrop(theme: theme)
            if let vm {
                if vm.stage == .finished {
                    WrapView(vm: vm) { dismiss() }.transition(.opacity)
                } else {
                    active(vm)
                }
                if let celebration = vm.pendingCelebration {
                    CelebrationOverlay(celebration: celebration) { vm.celebrationDismissed() }
                        .transition(.opacity).zIndex(10)
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .environment(\.worldTheme, theme)
        .animation(Theme.Motion.snappy, value: vm?.stage)
        .onAppear {
            if vm == nil {
                let args = ProcessInfo.processInfo.arguments
                let mode: SessionViewModel.AutoMode = args.contains("-demoWrap") ? .wrap
                    : (args.contains("-demoFeedback") ? .feedback : .off)
                vm = SessionViewModel(service: LearningService(context: context),
                                      speedRound: speedRound, auto: mode,
                                      worldIndex: worldIndex, testFormat: testFormat)
            }
        }
    }

    @ViewBuilder
    private func active(_ vm: SessionViewModel) -> some View {
        VStack(spacing: 0) {
            topBar(vm)
            Spacer(minLength: 0)
            if let q = vm.current {
                // No monolithic card: each element carries its own dark plate so the
                // world art stays the star of the screen.
                QuestionContainer(vm: vm, question: q)
                    .id(vm.index)
                    .frame(maxWidth: 680)
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
                        .font(.system(size: 30)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).contentShape(Rectangle())
                        .shadow(radius: 3)
                }
                .accessibilityLabel("End session")
                Spacer()
                Text(vm.movementLabel.uppercased())
                    .font(Theme.Font.label(13)).tracking(1.5).foregroundStyle(.white).shadow(radius: 2)
                Spacer()
                if vm.combo >= 3 {
                    Label("×\(vm.combo)", systemImage: "flame.fill")
                        .font(Theme.Font.number(16)).foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Capsule().fill(
                            LinearGradient(colors: [Color(red: 1, green: 0.55, blue: 0.15),
                                                    Color(red: 0.95, green: 0.3, blue: 0.1)],
                                           startPoint: .top, endPoint: .bottom)))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .contentTransition(.numericText(value: Double(vm.combo)))
                }
                Label("\(vm.xpEarned)", systemImage: "star.fill")
                    .font(Theme.Font.number(17)).foregroundStyle(Theme.Color.accent).shadow(radius: 2)
                    .contentTransition(.numericText(value: Double(vm.xpEarned)))
            }
            .animation(Theme.Motion.celebrate, value: vm.combo)
            ProgressView(value: vm.progress).tint(.white)
        }
        .padding(.horizontal, Theme.Metric.pad).padding(.top, 12)
    }
}

/// Picks the question format and bridges feedback/advance back to the view-model.
private struct QuestionContainer: View {
    let vm: SessionViewModel
    let question: PlannedQuestion

    var body: some View {
        let inFeedback = vm.stage == .feedback
        VStack(spacing: 24) {
            if question.format == .recognition {
                MultipleChoiceView(question: question, showFeedback: inFeedback,
                                   selected: vm.lastSelected, onSelect: { vm.answer($0) })
            } else {
                OpenResponseView(question: question, timed: vm.showTimer && question.timed,
                                 showFeedback: inFeedback, lastCorrect: vm.lastCorrect,
                                 onSubmit: { vm.answer($0) })
            }
            // The feedback slot is ALWAYS reserved so revealing an answer never
            // shifts the question or buttons; the pill just fades in place.
            // Correct answers auto-advance; only a miss waits for Continue.
            FeedbackBar(correct: vm.lastCorrect,
                        equation: "\(question.prompt.text) = \(question.prompt.answer)",
                        xp: vm.lastXP, mastered: vm.justMastered,
                        showsContinue: inFeedback && !vm.lastCorrect) { vm.next() }
                .opacity(inFeedback ? 1 : 0)
                .scaleEffect(inFeedback ? 1 : 0.85)
                .allowsHitTesting(inFeedback)
                .frame(height: 74)
        }
        .onAppear { vm.beginQuestion() }
        .animation(Theme.Motion.snappy, value: vm.stage)
    }
}
