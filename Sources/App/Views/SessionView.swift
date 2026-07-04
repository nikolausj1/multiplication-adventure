import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var worldIndex: Int = 0
    var speedRound: Bool = false
    var boss: Bool = false
    var testFormat: MasteryStage? = nil

    @State private var vm: SessionViewModel?
    private var theme: WorldTheme { .forWorld(worldIndex) }

    var body: some View {
        // Blur the whole scene while the STAR EARNED takeover is up, so the big
        // stars sit on a calm background instead of visual noise.
        let starShowing = vm?.pendingStarEarned != nil
        ZStack {
            WorldBackdrop(theme: theme)
                .blur(radius: starShowing ? 12 : 0)
            if let vm {
                if vm.stage == .finished {
                    WrapView(vm: vm) { dismiss() }.transition(.opacity)
                } else {
                    active(vm)
                        .blur(radius: starShowing ? 12 : 0)
                }
                if let starIndex = vm.pendingStarEarned {
                    StarEarnedOverlay(
                        worldName: WorldCatalog.worlds[safe: vm.worldStatBefore.index]?.name ?? "This world",
                        newStarIndex: starIndex) { vm.starEarnedDismissed() }
                        .transition(.opacity).zIndex(9)
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
                                      speedRound: speedRound, boss: boss, auto: mode,
                                      worldIndex: worldIndex, testFormat: testFormat)
                if args.contains("-demoStar") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { vm?.debugShowStar(2) }
                }
            }
        }
    }

    @ViewBuilder
    private func active(_ vm: SessionViewModel) -> some View {
        VStack(spacing: 0) {
            topBar(vm)
            Spacer(minLength: 0)
            if let q = vm.current {
                // Boss fights put the world's guardian on screen; every correct
                // answer lands a hit. Otherwise the question stands alone.
                if vm.bossWorldIndex != nil && Art.exists(theme.bossImage) {
                    HStack(alignment: .center, spacing: 4) {
                        BossPanel(theme: theme, hits: vm.correctCount, hpTotal: vm.bossHPTotal)
                            .frame(maxWidth: 400)
                        QuestionContainer(vm: vm, question: q)
                            .id(vm.index)
                            .frame(maxWidth: 620)
                    }
                    .padding(Theme.Metric.pad)
                } else {
                    QuestionContainer(vm: vm, question: q)
                        .id(vm.index)
                        .frame(maxWidth: 680)
                        .padding(Theme.Metric.pad)
                }
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
                if vm.bossWorldIndex != nil {
                    Label(theme.world.bossName.uppercased(), systemImage: "flag.checkered")
                        .font(Theme.Font.label(13)).tracking(1.5).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(
                            LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.2),
                                                    Color(red: 0.6, green: 0.1, blue: 0.15)],
                                           startPoint: .top, endPoint: .bottom)))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                } else {
                    Text(vm.movementLabel.uppercased())
                        .font(Theme.Font.label(13)).tracking(1.5).foregroundStyle(.white).shadow(radius: 2)
                }
                Spacer()
                if vm.showsWorldRing {
                    StarChip(fluent: vm.worldFluent, total: vm.worldTotal)
                }
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
            }
            .animation(Theme.Motion.celebrate, value: vm.combo)
            ProgressView(value: vm.progress).tint(.white)
        }
        .padding(.horizontal, Theme.Metric.pad).padding(.top, 12)
    }

}

/// Live world stars in the session header. When fluency crosses a star threshold
/// mid-session, the newest star slams in with a bounce and a sparkle burst.
private struct StarChip: View {
    let fluent: Int
    let total: Int

    @State private var shownFilled: Int = 0
    @State private var earnPulse = false

    var body: some View {
        let filled = WorldStars.filled(fluent: fluent, total: total)
        HStack(spacing: 4) {
            ForEach(0..<WorldStars.starCount, id: \.self) { i in
                StarGlyph(filled: i < filled, size: 16)
                    .scaleEffect(earnPulse && i == filled - 1 ? 1.7 : 1)
                    .rotationEffect(.degrees(earnPulse && i == filled - 1 ? 18 : 0))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.32)))
        .overlay {
            if earnPulse {
                ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 12)
                    .frame(width: 160, height: 160)
            }
        }
        .onAppear { shownFilled = filled }
        .onChange(of: filled) { _, newFilled in
            guard newFilled > shownFilled else { shownFilled = newFilled; return }
            shownFilled = newFilled
            withAnimation(.spring(response: 0.35, dampingFraction: 0.4)) { earnPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(Theme.Motion.snappy) { earnPulse = false }
            }
        }
        .accessibilityLabel("\(filled) of \(WorldStars.starCount) stars in this world")
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
                        xp: vm.lastXP, fluent: vm.justFluent, mastered: vm.justMastered,
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
