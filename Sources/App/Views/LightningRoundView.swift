import SwiftUI
import SwiftData

/// The True/False Lightning Round: a fast fluent-facts consolidation mode, entered
/// exactly parallel to the Speed Round (see MapView's header button + WorldSelection),
/// but fully isolated from the learning engine — no scheduler/Leitner/promotion
/// writes (see `LightningRoundViewModel` / `LearningService.finishLightningRound`).
/// Presented the same way `SessionView` is: an in-hierarchy overlay from the map.
struct LightningRoundView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    let worldIndex: Int
    var onClose: () -> Void = {}

    @State private var vm: LightningRoundViewModel?
    private var theme: WorldTheme { .forWorld(worldIndex) }
    private var compact: Bool { vSize == .compact }

    var body: some View {
        ZStack {
            WorldBackdrop(theme: theme)
            if let vm {
                if vm.stage == .finished {
                    LightningResultsView(vm: vm, onDone: onClose)
                        .transition(.opacity)
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
        .ignoresSafeArea(.keyboard)
        .environment(\.worldTheme, theme)
        .animation(Theme.Motion.snappy, value: vm?.stage)
        .onAppear {
            guard vm == nil else { return }
            let args = ProcessInfo.processInfo.arguments
            vm = LightningRoundViewModel(service: LearningService(context: context),
                                         auto: args.contains("-demoLightningResults"))
        }
    }

    @ViewBuilder
    private func active(_ vm: LightningRoundViewModel) -> some View {
        VStack(spacing: 0) {
            topBar(vm)
            Spacer(minLength: 0)
            if let s = vm.current {
                VStack(spacing: compact ? 10 : 24) {
                    LightningStatementView(statement: s, showFeedback: vm.stage == .feedback,
                                           selectedTrue: vm.lastSelectedTrue,
                                           onSelect: { vm.answer($0) })
                    // Reuses the app's existing neutral-soft miss reveal (the same
                    // component regular quests use) — same feel, no punishment beat.
                    FeedbackBar(correct: vm.lastCorrect, equation: s.trueEquationText,
                               xp: 0, mastered: false, showsContinue: false) {}
                        .opacity(vm.stage == .feedback ? 1 : 0)
                        .scaleEffect(vm.stage == .feedback ? 1 : 0.85)
                        .allowsHitTesting(false)
                        .frame(height: compact ? 50 : 74)
                }
                .id(vm.index)
                .frame(maxWidth: 680)
                .padding(compact ? 8 : Theme.Metric.pad)
            }
            Spacer(minLength: 0)
        }
    }

    private func topBar(_ vm: LightningRoundViewModel) -> some View {
        HStack(spacing: 14) {
            // Quitting mid-round abandons it outright: no partial best, no partial
            // XP (see LightningRoundViewModel — score is defined as "out of 20").
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30)).foregroundStyle(.white)
                    .frame(width: 48, height: 48).contentShape(Rectangle())
                    .shadow(radius: 3)
            }
            .accessibilityLabel("End Lightning Round")
            Spacer()
            Label("\(min(vm.index + 1, vm.total))/\(vm.total)", systemImage: "bolt.fill")
                .font(Theme.Font.label(14)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7).darkPlate(corner: 18)
            Spacer()
            LightningClock()
        }
        .padding(.horizontal, Theme.Metric.pad).padding(.top, compact ? 4 : 12)
    }
}

/// Count-up clock — no countdowns anywhere (design rule). Same visual language as
/// OpenResponseView's timed stopwatch chip.
private struct LightningClock: View {
    @State private var start = Date.now
    var body: some View {
        TimelineView(.periodic(from: start, by: 0.1)) { ctx in
            Label(String(format: "%.1fs", max(0, ctx.date.timeIntervalSince(start))), systemImage: "stopwatch.fill")
                .font(Theme.Font.number(18)).foregroundStyle(Theme.Color.accent)
                .monospacedDigit()
                .padding(.horizontal, 14).padding(.vertical, 7)
                .darkPlate(corner: 20)
        }
    }
}

/// Two big, thumb-friendly TRUE/FALSE keys — styled via the same Theme token
/// layer as every other big button in the app. FALSE deliberately avoids the
/// harsh alarm-red the in-quest True/False review key uses (design rule: no
/// red/buzzer feel) in favor of `Theme.Color.gentle`, the app's neutral tone.
private struct LightningStatementView: View {
    @Environment(\.verticalSizeClass) private var vSize
    let statement: LightningRound.Statement
    let showFeedback: Bool
    let selectedTrue: Bool?
    let onSelect: (Bool) -> Void

    private var compact: Bool { vSize == .compact }

    var body: some View {
        VStack(spacing: compact ? 14 : 30) {
            PromptText(statement.displayText)
            if !compact {
                Text("TRUE or FALSE?")
                    .font(Theme.Font.label(16)).tracking(3)
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
            HStack(spacing: compact ? 16 : 22) {
                key(isTrueKey: true, title: "TRUE", icon: "checkmark", tint: Theme.Color.correct)
                key(isTrueKey: false, title: "FALSE", icon: "xmark", tint: Theme.Color.gentle)
            }
            .frame(maxWidth: 620)
        }
        .animation(Theme.Motion.snappy, value: showFeedback)
    }

    private func key(isTrueKey: Bool, title: String, icon: String, tint: Color) -> some View {
        let isCorrectKey = isTrueKey == statement.isTrue
        let isPicked = selectedTrue == isTrueKey
        let dimmed = showFeedback && !isCorrectKey
        let base: Color = showFeedback ? (isCorrectKey ? Theme.Color.correct
                                          : (isPicked ? Color(white: 0.45) : tint))
                                       : tint
        return Button { if !showFeedback { onSelect(isTrueKey) } } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 40, weight: .heavy))
                Text(title).font(Theme.Font.display(30))
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
        .buttonStyle(ChunkyKeyStyle(base: base, deep: base.shaded(by: -0.35), corner: 26))
        .disabled(showFeedback)
        .saturation(dimmed ? 0.45 : 1)
        .opacity(dimmed ? (isPicked ? 0.8 : 0.55) : 1)
        .scaleEffect(showFeedback && isCorrectKey ? 1.05 : 1)
        .shadow(color: showFeedback && isCorrectKey ? Theme.Color.correct.opacity(0.75) : .clear,
                radius: 14)
        .overlay {
            if showFeedback && isCorrectKey {
                ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 10)
                    .frame(width: 190, height: 190)
            }
        }
        .accessibilityLabel(title)
    }
}

/// Results screen: beat-your-best framing mirroring the Speed Round's wrap
/// conventions (stat row, PB card, "Back to Map"), but standalone — this mode
/// never builds a `SessionViewModel`, so it can't reuse `WrapView`.
private struct LightningResultsView: View {
    @Environment(\.worldTheme) private var theme
    @Environment(\.verticalSizeClass) private var vSize
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]
    let vm: LightningRoundViewModel
    let onDone: () -> Void

    private var compact: Bool { vSize == .compact }
    private var profile: Profile? { activeProfiles.first }

    var body: some View {
        Group { if compact { ScrollView { stack } } else { stack } }
            .padding(compact ? 14 : Theme.Metric.pad + 8)
            .frame(maxWidth: 500)
            .darkPlate()
            .padding(Theme.Metric.pad)
            .background {
                if vm.isNewBest {
                    ParticleBurst(kind: .confetti,
                                  colors: [Theme.Color.accent, Theme.Color.correct,
                                           theme.primary, .white, theme.accent],
                                  origin: UnitPoint(x: 0.5, y: 0.3), count: 90)
                        .frame(width: 900, height: 800)
                }
            }
    }

    @ViewBuilder
    private var stack: some View {
        if vm.unavailable {
            VStack(spacing: 16) {
                Image(systemName: "bolt.slash.fill").font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Not ready yet").font(Theme.Font.display(compact ? 22 : 28)).foregroundStyle(.white)
                Text("Get some facts fluent in practice first — the Lightning Round is for facts you already know!")
                    .font(Theme.Font.body()).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Button(action: onDone) {
                    Text("Back to Map").font(Theme.Font.display(20))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .buttonStyle(ChunkyKeyStyle(base: theme.primary, deep: theme.deep, corner: Theme.Metric.corner))
            }
        } else {
            VStack(spacing: compact ? 12 : 22) {
                Image(systemName: vm.isNewBest ? "trophy.fill" : "bolt.fill")
                    .font(.system(size: compact ? 48 : 72))
                    .foregroundStyle(vm.isNewBest ? Theme.Color.accent : Theme.Color.correct)
                    .symbolRenderingMode(.hierarchical)
                    .background {
                        ParticleBurst(kind: .stars, colors: [Theme.Color.accent, .white], count: 14)
                            .frame(width: 260, height: 260)
                    }
                Text(vm.isNewBest ? "New Lightning best!" : "Lightning Round complete!")
                    .font(Theme.Font.display(compact ? 24 : 34)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: compact ? 14 : 28) {
                    stat("\(vm.correctCount)/\(vm.total)", "correct")
                    stat(String(format: "%.1fs", vm.elapsed), "time")
                    stat("+\(vm.xpEarned)", "XP", tint: Theme.Color.accent)
                }

                bestCard

                Button(action: onDone) {
                    Text("Back to Map").font(Theme.Font.display(20))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .buttonStyle(ChunkyKeyStyle(base: theme.primary, deep: theme.deep, corner: Theme.Metric.corner))
            }
        }
    }

    private func stat(_ value: String, _ label: String, tint: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.Font.number(compact ? 22 : 30)).foregroundStyle(tint)
            Text(label).font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.65))
        }
    }

    @ViewBuilder
    private var bestCard: some View {
        if let p = profile, p.hasLightningResult {
            HStack {
                Label("BEST", systemImage: "star.fill")
                    .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.accent)
                Spacer()
                Text("\(p.bestLightningScore)/\(vm.total) · \(String(format: "%.1fs", p.bestLightningTime))")
                    .font(Theme.Font.label(14)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
