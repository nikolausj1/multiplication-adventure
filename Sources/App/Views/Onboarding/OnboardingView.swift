import SwiftUI
import SwiftData

/// First-run flow (once per profile): name → grade → avatar → go. Shown by
/// RootView under the splash until `profile.onboarded` flips true.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    private enum Step: Int, CaseIterable { case welcome, name, grade, avatar, ready }
    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var grade = ""
    // The explorer opens front and center (carouselOrder puts him mid-row).
    @State private var avatarKey = "avatar1"
    @FocusState private var nameFocused: Bool

    private var compact: Bool { vSize == .compact }
    private let grades = ["Pre-K", "K", "1", "2", "3", "4", "5"]

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                header
                // iPad centers the page vertically; iPhone landscape top-anchors
                // it (fixed small gap above, expanding space below) so the name
                // field + Next sit in the top strip, clear of the keyboard.
                if compact {
                    Color.clear.frame(height: 8)
                } else {
                    Spacer(minLength: 12)
                }
                Group {
                    switch step {
                    case .welcome: welcomePage
                    case .name:   namePage
                    case .grade:  gradePage
                    case .avatar: avatarPage
                    case .ready:  readyPage
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing),
                                        removal: .move(edge: .leading))
                            .combined(with: .opacity))
                Spacer(minLength: 0)
                if !compact { Spacer(minLength: 0) }
            }
            .padding(compact ? 12 : Theme.Metric.pad)
        }
        // No text field can be shoved under the keyboard: the layout ignores the
        // keyboard inset and keeps the name row anchored high (see namePage).
        .ignoresSafeArea(.keyboard)
        .animation(Theme.Motion.snappy, value: step)
        .onAppear {
            // Debug: jump straight to a step for screenshots.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-onboardingStep"), i + 1 < args.count,
               let n = Int(args[i + 1]), let s = Step(rawValue: n) {
                name = name.isEmpty ? "Explorer" : name
                step = s
            }
        }
    }

    // Solid night-sky backdrop: the world map (and splash art that shows it)
    // stays a surprise until onboarding finishes.
    private var backdrop: some View {
        LinearGradient(colors: [Color(red: 0.11, green: 0.12, blue: 0.30),
                                Color(red: 0.05, green: 0.05, blue: 0.14)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).darkPlate(corner: 22)
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)
            // Progress: one capsule segment per step (welcome doesn't count).
            HStack(spacing: 6) {
                ForEach(Step.allCases.filter { $0 != .welcome }, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.Color.accent : .white.opacity(0.2))
                        .frame(height: 8)
                }
            }
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: Pages

    /// A calm landing beat after the splash — the keyboard shouldn't be the
    /// first thing that greets a new player.
    private var welcomePage: some View {
        VStack(spacing: compact ? 14 : 24) {
            Text("Ready for an adventure?")
                .font(Theme.Font.display(compact ? 30 : 44)).foregroundStyle(.white)
                .shadow(radius: 4)
            Text("Seven worlds of multiplication are waiting for a hero.")
                .font(Theme.Font.body(compact ? 16 : 22)).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button {
                advance()
            } label: {
                Text("Let's get started!")
                    .font(Theme.Font.display(compact ? 22 : 28))
                    .padding(.horizontal, compact ? 34 : 48)
                    .padding(.vertical, compact ? 13 : 20)
            }
            .buttonStyle(ChunkyKeyStyle(base: Theme.Color.correct,
                                        deep: Theme.Color.correct.shaded(by: -0.35),
                                        corner: Theme.Metric.corner))
            .padding(.top, compact ? 4 : 12)
        }
    }

    private var namePage: some View {
        VStack(spacing: compact ? 12 : 22) {
            Text("What's your name, adventurer?")
                .font(Theme.Font.display(compact ? 22 : 30)).foregroundStyle(.white)
                .shadow(radius: 4)
            // iPad stacks field over Next; iPhone landscape puts them side by
            // side so the whole input row stays in the top strip above the
            // keyboard (the root ignores the keyboard inset, so nothing shifts).
            if compact {
                HStack(spacing: 12) { nameField; nextButton }
            } else {
                nameField
                nextButton
            }
        }
        .onAppear { nameFocused = true }
    }

    private var nameField: some View {
        TextField("", text: $name, prompt: Text("Your name")
            .foregroundStyle(.white.opacity(0.35)))
            .font(Theme.Font.display(compact ? 22 : 26)).foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .submitLabel(.next)
            .onSubmit { if canAdvance { advance() } }
            .onChange(of: name) { _, new in
                if new.count > 12 { name = String(new.prefix(12)) }
            }
            .frame(maxWidth: compact ? 260 : 340)
            .padding(.vertical, compact ? 11 : 14).padding(.horizontal, 20)
            .darkPlate(corner: 18)
    }

    private var gradePage: some View {
        VStack(spacing: compact ? 14 : 26) {
            Text("What grade are you going to be in?")
                .font(Theme.Font.display(compact ? 22 : 30)).foregroundStyle(.white)
                .shadow(radius: 4)
            HStack(spacing: compact ? 10 : 16) {
                ForEach(grades, id: \.self) { g in
                    Button {
                        grade = g
                        Feedback.fire(.keyTap)
                    } label: {
                        Text(g)
                            .font(Theme.Font.display(g.count > 1 ? (compact ? 15 : 20)
                                                               : (compact ? 22 : 28)))
                            .foregroundStyle(.white)
                            .frame(width: compact ? 62 : 88, height: compact ? 62 : 88)
                    }
                    .buttonStyle(ChunkyKeyStyle(base: Theme.Color.primary,
                                                deep: Theme.Color.primary.shaded(by: -0.35),
                                                corner: compact ? 31 : 44))
                    .overlay {
                        if grade == g {
                            Circle().strokeBorder(Theme.Color.accent, lineWidth: 4)
                                .shadow(color: Theme.Color.accent.opacity(0.7), radius: 8)
                        }
                    }
                    .scaleEffect(grade == g ? 1.12 : 1)
                    .animation(Theme.Motion.celebrate, value: grade)
                }
            }
            nextButton
        }
    }

    private var avatarPage: some View {
        VStack(spacing: compact ? 8 : 18) {
            Text("Pick your explorer!")
                .font(Theme.Font.display(compact ? 22 : 30)).foregroundStyle(.white)
                .shadow(radius: 4)
            AvatarCarousel(selected: $avatarKey, itemSize: compact ? 130 : 230)
            nextButton
                .padding(.top, compact ? 4 : 20)
        }
    }

    private var readyPage: some View {
        VStack(spacing: compact ? 12 : 24) {
            AvatarBadge(key: avatarKey, size: compact ? 118 : 230)
                .shadow(color: Theme.Color.accent.opacity(0.4), radius: 20)
            Text("You're ready, \(name.trimmingCharacters(in: .whitespaces))!")
                .font(Theme.Font.display(compact ? 28 : 46)).foregroundStyle(.white)
                .shadow(radius: 4)
            Text("Seven worlds. Seven guardians. Let's go!")
                .font(Theme.Font.body(compact ? 16 : 24)).foregroundStyle(.white.opacity(0.85))
            Button {
                finish()
            } label: {
                Text("Start the adventure!")
                    .font(Theme.Font.display(compact ? 22 : 28))
                    .padding(.horizontal, compact ? 34 : 48)
                    .padding(.vertical, compact ? 13 : 20)
            }
            .buttonStyle(ChunkyKeyStyle(base: Theme.Color.accent,
                                        deep: Theme.Color.accent.shaded(by: -0.35),
                                        corner: Theme.Metric.corner))
        }
    }

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            Text("Next")
                .font(Theme.Font.display(compact ? 20 : 26))
                .padding(.horizontal, compact ? 38 : 64)
                .padding(.vertical, compact ? 12 : 18)
        }
        .buttonStyle(ChunkyKeyStyle(base: Theme.Color.correct,
                                    deep: Theme.Color.correct.shaded(by: -0.35),
                                    corner: Theme.Metric.corner))
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.4)
    }

    private var canAdvance: Bool {
        switch step {
        case .name:  return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .grade: return !grade.isEmpty
        default:     return true
        }
    }

    private func advance() {
        nameFocused = false
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    private func finish() {
        guard let p = activeProfiles.first else { return }
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.grade = grade
        p.avatarSymbol = avatarKey
        withAnimation(.easeOut(duration: 0.5)) { p.onboarded = true }
        try? context.save()
        // No sound here — the avatar-flight transition plays silently.
    }
}
