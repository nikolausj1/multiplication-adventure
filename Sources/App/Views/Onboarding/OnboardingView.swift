import SwiftUI
import SwiftData

/// First-run flow (once per profile): name → grade → avatar → go. Shown by
/// RootView under the splash until `profile.onboarded` flips true.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    private enum Step: Int, CaseIterable { case name, grade, avatar, ready }
    @State private var step: Step = .name
    @State private var name = ""
    @State private var grade = ""
    @State private var avatarKey = "avatar1"
    @FocusState private var nameFocused: Bool

    private let grades = ["Pre-K", "K", "1", "2", "3", "4", "5"]

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                Group {
                    switch step {
                    case .name:   namePage
                    case .grade:  gradePage
                    case .avatar: avatarPage
                    case .ready:  readyPage
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing),
                                        removal: .move(edge: .leading))
                            .combined(with: .opacity))
                // Content lives in the upper half so the landscape keyboard
                // (bottom ~45%) never covers the name field.
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .padding(Theme.Metric.pad)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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

    private var backdrop: some View {
        ZStack {
            Color.black
            if Art.exists("splash") {
                Color.clear
                    .overlay(Image("splash").resizable().scaledToFill())
                    .clipped()
                    .opacity(0.35)
            } else {
                LinearGradient(colors: [Theme.Color.primary.shaded(by: -0.5), .black],
                               startPoint: .top, endPoint: .bottom)
            }
            Color.black.opacity(0.3)
        }
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
            .opacity(step == .name ? 0 : 1)
            .disabled(step == .name)
            // Progress: one capsule segment per step.
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.Color.accent : .white.opacity(0.2))
                        .frame(height: 8)
                }
            }
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: Pages

    private var namePage: some View {
        VStack(spacing: 22) {
            Text("What's your name, adventurer?")
                .font(Theme.Font.display(30)).foregroundStyle(.white)
                .shadow(radius: 4)
            HStack(spacing: 12) {
                TextField("", text: $name, prompt: Text("Your name")
                    .foregroundStyle(.white.opacity(0.35)))
                    .font(Theme.Font.display(26)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .onSubmit { if canAdvance { advance() } }
                    .onChange(of: name) { _, new in
                        if new.count > 12 { name = String(new.prefix(12)) }
                    }
                    .frame(maxWidth: 340)
                    .padding(.vertical, 14).padding(.horizontal, 20)
                    .darkPlate(corner: 18)
            }
            nextButton
        }
        .onAppear { nameFocused = true }
    }

    private var gradePage: some View {
        VStack(spacing: 26) {
            Text("What grade are you going to be in?")
                .font(Theme.Font.display(30)).foregroundStyle(.white)
                .shadow(radius: 4)
            HStack(spacing: 16) {
                ForEach(grades, id: \.self) { g in
                    Button {
                        grade = g
                        Feedback.fire(.keyTap)
                    } label: {
                        Text(g)
                            .font(Theme.Font.display(g.count > 1 ? 20 : 28))
                            .foregroundStyle(.white)
                            .frame(width: 88, height: 88)
                    }
                    .buttonStyle(ChunkyKeyStyle(base: Theme.Color.primary,
                                                deep: Theme.Color.primary.shaded(by: -0.35),
                                                corner: 44))
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
        VStack(spacing: 18) {
            Text("Pick your explorer!")
                .font(Theme.Font.display(30)).foregroundStyle(.white)
                .shadow(radius: 4)
            AvatarCarousel(selected: $avatarKey, itemSize: 150)
            nextButton
                .padding(.top, 20)
        }
    }

    private var readyPage: some View {
        VStack(spacing: 20) {
            AvatarBadge(key: avatarKey, size: 130)
                .shadow(color: Theme.Color.accent.opacity(0.4), radius: 16)
            Text("You're ready, \(name.trimmingCharacters(in: .whitespaces))!")
                .font(Theme.Font.display(34)).foregroundStyle(.white)
                .shadow(radius: 4)
            Text("Seven worlds. Seven guardians. Let's go!")
                .font(Theme.Font.body(18)).foregroundStyle(.white.opacity(0.85))
            Button {
                finish()
            } label: {
                Text("Start the adventure!")
                    .font(Theme.Font.display(22))
                    .padding(.horizontal, 36).padding(.vertical, 16)
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
                .font(Theme.Font.display(20))
                .padding(.horizontal, 44).padding(.vertical, 13)
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
        Feedback.fire(.levelUp)
    }
}
