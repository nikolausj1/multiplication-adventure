import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var worldIndex: Int = 0
    var speedRound: Bool = false
    var boss: Bool = false
    var testFormat: MasteryStage? = nil

    @State private var vm: SessionViewModel?
    /// First-ever visit to this world: hold the questions and let the kid take
    /// in the place — full backdrop, world title, tap to begin.
    @State private var showWorldIntro = false
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
                    if vm.didPause {
                        // Paused for the day — straight back to the map, no wrap.
                        Color.clear.onAppear { dismiss() }
                    } else {
                        WrapView(vm: vm) { dismiss() }.transition(.opacity)
                    }
                } else {
                    active(vm)
                        .blur(radius: starShowing ? 12 : 0)
                }
                if let starIndex = vm.pendingStarEarned {
                    StarEarnedOverlay(
                        worldName: WorldCatalog.worlds[safe: vm.worldStatBefore.index]?.name ?? "This world",
                        newStarIndex: starIndex,
                        totalStars: vm.starsPerWorldGoal) { vm.starEarnedDismissed() }
                        .transition(.opacity).zIndex(9)
                }
                if let celebration = vm.pendingCelebration {
                    CelebrationOverlay(celebration: celebration) { vm.celebrationDismissed() }
                        .transition(.opacity).zIndex(10)
                }
            } else if !showWorldIntro {
                ProgressView().tint(.white)
            }
            if showWorldIntro {
                WorldIntroOverlay(theme: theme, worldNumber: worldIndex + 1,
                                  name: WorldCatalog.worlds[safe: worldIndex]?.name ?? "") {
                    withAnimation(.easeInOut(duration: 0.5)) { showWorldIntro = false }
                    let service = LearningService(context: context)
                    service.activeProfile().markWorldIntroSeen(worldIndex)
                    try? context.save()
                    buildVM()   // clock and first question start when the curtain lifts
                }
                .zIndex(20)
                .transition(.opacity)
            }
        }
        .environment(\.worldTheme, theme)
        .animation(Theme.Motion.snappy, value: vm?.stage)
        .onChange(of: scenePhase) { _, phase in
            // The quest clock counts active screen time only.
            if phase == .active { vm?.clockRun() } else { vm?.clockPause() }
        }
        .onAppear {
            guard vm == nil, !showWorldIntro else { return }
            let args = ProcessInfo.processInfo.arguments
            let isQuest = !speedRound && !boss && testFormat == nil
            let verifyLaunch = args.contains("-autostartSession")   // debug autoplay skips the reveal
            if isQuest, args.contains("-forceWorldIntro")
                || (!verifyLaunch && !LearningService(context: context).activeProfile().hasSeenWorldIntro(worldIndex)) {
                showWorldIntro = true   // vm builds when the curtain lifts
                return
            }
            buildVM()
        }
    }

    private func buildVM() {
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
                        BossPanel(theme: theme, hits: vm.correctCount, hpTotal: vm.bossHPTotal,
                                  lastHitCritical: vm.lastHitCritical)
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
        HStack(spacing: 14) {
            Button { vm.stop() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30)).foregroundStyle(.white)
                    .frame(width: 48, height: 48).contentShape(Rectangle())
                    .shadow(radius: 3)
            }
            .accessibilityLabel("End session")
            if vm.bossWorldIndex != nil {
                // Boss fights: the guardian's HP bar is the progress — no meter here.
                Spacer()
                Label(theme.world.bossName.uppercased(), systemImage: "flag.checkered")
                    .font(Theme.Font.label(13)).tracking(1.5).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(
                        LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.2),
                                                Color(red: 0.6, green: 0.1, blue: 0.15)],
                                       startPoint: .top, endPoint: .bottom)))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                Spacer()
            } else {
                QuestMeter(progress: vm.isQuest ? vm.questMeter : vm.progress,
                           complete: vm.questComplete, phase: vm.questPhase)
                    .frame(maxWidth: .infinity)
            }
            if vm.showsWorldRing {
                StarChip(filled: vm.shownStars, total: vm.starsPerWorldGoal)
            }
            // Always present so the header never reflows — dim until it ignites at 3.
            ComboChip(combo: vm.streakDisplay)
        }
        .animation(Theme.Motion.celebrate, value: vm.streakDisplay)
        .padding(.horizontal, Theme.Metric.pad).padding(.top, 12)
    }

}

/// The Quest Meter: a chunky bar that fills as the day's work gets done. Every
/// answer moves it — review nudges, star-ladder work jumps. Each round wears its
/// own color (blue warm-up → green meet → gold train) and the bar takes an
/// electric jolt at each transition: a white flash, a height pop, and sparks off
/// the fill's leading edge. The color always matches the input on screen: green
/// = cards, blue/gold = keypad. Completion glows gold with a final jolt.
private struct QuestMeter: View {
    let progress: Double
    let complete: Bool
    var phase: QuestPhase? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Colors follow this, not `phase` directly, so the color arrives WITH the
    /// jolt (both delayed a beat past the question swap, where eyes can catch it).
    @State private var shownPhase: QuestPhase?
    @State private var appeared = false
    @State private var pop = false       // brief thickness spring
    @State private var flash = false     // white sweep over the fill
    @State private var sparkID = 0       // > 0 → burst exists; bump retriggers

    /// Blue warm-up → green cards → gold train; the ramp ends on gold, where the
    /// star charges. Non-quest days (phase nil) and completion are gold too.
    private var fillColors: [Color] {
        if complete { return Self.gold }
        switch shownPhase {
        case .warmup: return [Color(red: 0.45, green: 0.82, blue: 1.0),
                              Color(red: 0.12, green: 0.5, blue: 0.95)]
        case .meet:   return [Color(red: 0.55, green: 0.88, blue: 0.45),
                              Color(red: 0.15, green: 0.62, blue: 0.25)]
        case .train, .none: return Self.gold
        }
    }
    private static let gold = [Color(red: 1, green: 0.84, blue: 0.35),
                               Color(red: 0.95, green: 0.6, blue: 0.1)]

    var body: some View {
        GeometryReader { geo in
            let fillWidth = progress <= 0.005 ? 0
                : max(14, geo.size.width * min(progress, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.38))
                Capsule()
                    .fill(LinearGradient(colors: fillColors,
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: fillWidth)
                    .shadow(color: complete ? Theme.Color.accent.opacity(0.9) : .clear, radius: 6)
                Capsule().fill(.white)
                    .frame(width: fillWidth)
                    .opacity(flash ? 0.9 : 0)
                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
            }
            .overlay(alignment: .leading) {
                if sparkID > 0 {
                    ParticleBurst(kind: .stars,
                                  colors: [.white, fillColors[0]],
                                  count: 16, seed: UInt64(sparkID))
                        .frame(width: 150, height: 150)
                        .offset(x: fillWidth - 75, y: -68)
                        .id(sparkID)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 13)
        .scaleEffect(y: pop ? 1.9 : 1)
        .animation(Theme.Motion.snappy, value: progress)
        .animation(.easeInOut(duration: 0.3), value: shownPhase)
        .animation(Theme.Motion.celebrate, value: complete)
        .onAppear { shownPhase = phase; appeared = true }
        .onChange(of: phase) { _, newPhase in
            guard appeared, newPhase != nil, newPhase != shownPhase else {
                shownPhase = newPhase; return
            }
            // Wait out the question swap so the jolt lands where eyes can see it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shownPhase = newPhase
                jolt()
            }
        }
        .onChange(of: complete) { _, done in
            if done { jolt() }   // the gold flip hits like a transition too
        }
        .accessibilityLabel("Quest progress \(Int(min(progress, 1) * 100)) percent")
    }

    private func jolt() {
        guard !reduceMotion else { return }   // Reduce Motion: color crossfade only
        sparkID += 1
        flash = true
        withAnimation(.spring(response: 0.16, dampingFraction: 0.4)) { pop = true }
        withAnimation(.easeOut(duration: 0.5)) { flash = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { pop = false }
        }
    }
}

/// In-session combo flame. Always rendered (fixed slot — the header never
/// reflows); dim while the streak builds, ignites orange at 3+.
private struct ComboChip: View {
    let combo: Int
    private var lit: Bool { combo >= 3 }

    var body: some View {
        Label("×\(combo)", systemImage: "flame.fill")
            .font(Theme.Font.number(16))
            .foregroundStyle(lit ? .white : .white.opacity(0.45))
            .padding(.horizontal, 11).padding(.vertical, 6)
            .frame(minWidth: 64)
            .background(Capsule().fill(lit
                ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.55, blue: 0.15),
                                                        Color(red: 0.95, green: 0.3, blue: 0.1)],
                                               startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(Color.black.opacity(0.32))))
            .shadow(color: .black.opacity(lit ? 0.3 : 0), radius: 3, y: 2)
            .scaleEffect(lit ? 1 : 0.94)
            .contentTransition(.numericText(value: Double(combo)))
            .animation(Theme.Motion.celebrate, value: lit)
            .accessibilityLabel("Streak \(combo) in a row")
    }
}

/// The world's star sockets in the session header. Frozen until the quest
/// completes — then the new star arrives with a bounce and a sparkle burst
/// (right after the full-screen slam).
private struct StarChip: View {
    let filled: Int
    var total: Int = WorldCatalog.starsPerWorld

    @State private var shownFilled: Int = 0
    @State private var earnPulse = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { i in
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
        .accessibilityLabel("\(filled) of \(total) stars in this world")
    }
}

/// Picks the question format and bridges feedback/advance back to the view-model.
private struct QuestionContainer: View {
    let vm: SessionViewModel
    let question: PlannedQuestion

    var body: some View {
        let inFeedback = vm.stage == .feedback
        VStack(spacing: 24) {
            if question.trueFalse {
                TrueFalseView(question: question, showFeedback: inFeedback,
                              selected: vm.lastSelected, onSelect: { vm.answer($0) })
            } else if question.format == .recognition {
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
                        xp: vm.lastXP, hotStreak: vm.hotStreakReached ?? 0, wasFast: vm.wasFast,
                        mastered: vm.justMastered,
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

/// The dramatic first-entry reveal: the world's art breathes for a beat with
/// its title front and center — no questions until the kid taps.
private struct WorldIntroOverlay: View {
    let theme: WorldTheme
    let worldNumber: Int
    let name: String
    let onBegin: () -> Void

    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            WorldBackdrop(theme: theme, darken: 0.18)
            VStack(spacing: 16) {
                Text("WORLD \(worldNumber)")
                    .font(Theme.Font.label(24)).tracking(7)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.7), radius: 6, y: 2)
                Text(name)
                    .font(Theme.Font.display(72))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 14, y: 5)
                    .scaleEffect(appeared ? 1 : 1.18)
            }
            .opacity(appeared ? 1 : 0)
            VStack {
                Spacer()
                Text("TAP TO BEGIN")
                    .font(Theme.Font.label(18)).tracking(4)
                    .foregroundStyle(.white.opacity(pulse ? 0.9 : 0.45))
                    .shadow(color: .black.opacity(0.7), radius: 6, y: 2)
                    .padding(.bottom, 46)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Feedback.fire(.keyTap)
            onBegin()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { appeared = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
