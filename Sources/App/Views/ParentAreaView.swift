import SwiftUI
import SwiftData

/// Parent area: the transparent dashboard plus a gated Manage section (profiles,
/// reset, settings). Destructive actions sit behind a 2-digit × 2-digit parent gate;
/// viewing the dashboard stays open (§2).
struct ParentAreaView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    private var service: LearningService { LearningService(context: context) }

    @State private var showGate = false
    @State private var pending: (() -> Void)?

    @State private var showAdd = false
    @State private var addName = ""
    @State private var renameTarget: Profile?
    @State private var renameText = ""
    @State private var deleteTarget: Profile?
    @State private var resetTarget: Profile?

    // Developer / testing
    @State private var devUnlocked = false   // gate per sheet-presentation; spoils world names otherwise
    @State private var testWorld = 0
    @State private var testLaunch: WorldSelection?
    @State private var showCert = false
    @State private var startOverTarget: Profile?

    private let avatars = AvatarCatalog.keys
    @State private var howOpen = false

    var body: some View {
        ZStack {
            // Dimmed map behind the card; tap outside to dismiss.
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            card
                .frame(maxWidth: 1180, maxHeight: 850)
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            if showGate { gateOverlay.zIndex(5) }
        }
        .presentationBackground(.clear)
        .onAppear {
            // Screenshot hooks (simulator verification only).
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-openGate") { showGate = true }
            if args.contains("-openHow") { howOpen = true }
            if args.contains("-openDev") { devUnlocked = true }
            if args.contains("-testStartOver") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { performStartOver(profiles.first(where: { $0.isActive })) }
            }
        }
        .sheet(isPresented: $showCert) { CertificateView(name: activeName) }
        .fullScreenCover(item: $testLaunch) { sel in
            SessionView(worldIndex: sel.id, speedRound: sel.speed, boss: sel.boss, testFormat: sel.testFormat)
                .environment(\.worldTheme, .forWorld(sel.id))
        }
        .alert("New profile", isPresented: $showAdd) {
            TextField("Name", text: $addName)
            Button("Create") { _ = service.createProfile(name: addName, avatar: avatars.randomElement()!); addName = "" }
            Button("Cancel", role: .cancel) { addName = "" }
        }
        .alert("Rename profile", isPresented: Binding(get: { renameTarget != nil },
                                                      set: { if !$0 { renameTarget = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") { if let t = renameTarget { service.rename(t, to: renameText) }; renameTarget = nil }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .alert("Delete profile?", isPresented: Binding(get: { deleteTarget != nil },
                                                       set: { if !$0 { deleteTarget = nil } })) {
            Button("Delete", role: .destructive) { if let t = deleteTarget { service.delete(t) }; deleteTarget = nil }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: { Text("This permanently removes the profile and all its progress.") }
        .alert("Reset progress?", isPresented: Binding(get: { resetTarget != nil },
                                                       set: { if !$0 { resetTarget = nil } })) {
            Button("Reset", role: .destructive) { if let t = resetTarget { service.resetProgress(t) }; resetTarget = nil }
            Button("Cancel", role: .cancel) { resetTarget = nil }
        } message: { Text("This returns the profile to brand-new. It cannot be undone.") }
        .alert("Start over?", isPresented: Binding(get: { startOverTarget != nil },
                                                   set: { if !$0 { startOverTarget = nil } })) {
            Button("Start over", role: .destructive) {
                let t = startOverTarget
                startOverTarget = nil
                performStartOver(t)
            }
            Button("Cancel", role: .cancel) { startOverTarget = nil }
        } message: { Text("Wipes progress AND name, avatar, and grade — the app begins again with the first-time setup. It cannot be undone.") }
    }

    /// Wipe identity + progress, tell the root to re-run onboarding, then close.
    /// The notification (not the @Query onboarded-flip) is what re-arms the gate:
    /// the query can stay stale across this cover's dismissal.
    private func performStartOver(_ profile: Profile?) {
        guard let profile else { return }
        service.startOver(profile)
        NotificationCenter.default.post(name: .startOverRequested, object: nil)
        dismiss()
    }

    private func gated(_ action: @escaping () -> Void) { pending = action; showGate = true }

    /// Uppercase tracked section header with a small tinted icon — the parent-area
    /// counterpart of the kid modals' header style.
    private func sectionHeader(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.primary)
            Text(title.uppercased())
                .font(Theme.Font.label(13)).tracking(1.5)
                .foregroundStyle(Theme.Color.inkSoft)
        }
    }

    private var activeName: String { profiles.first(where: { $0.isActive })?.name ?? "Champion" }
    private var activeGoal: Int {
        profiles.first(where: { $0.isActive })?.starsPerWorldGoal ?? WorldCatalog.starsPerWorld
    }

    // MARK: The modal card — controls on the left, dashboard on the right

    private var card: some View {
        VStack(spacing: 0) {
            Text("Parent Area")
                .font(Theme.Font.display(30)).foregroundStyle(Theme.Color.ink)
                .padding(.top, 28).padding(.bottom, 24)
            HStack(alignment: .top, spacing: Theme.Metric.gap) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Metric.gap) {
                        profilesCard
                        settingsCard
                        howItWorksCard
                        developerCard
                    }
                    .padding(.bottom, Theme.Metric.pad)
                }
                .frame(width: 350)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Metric.gap) {
                        identityHeader
                        DashboardView()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Theme.Metric.pad)
                }
            }
            .padding(.horizontal, Theme.Metric.pad)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.93, green: 0.95, blue: 0.98),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
        .overlay(alignment: .topLeading) { ModalCloseButton { dismiss() }.padding(14) }
        .compositingGroup()   // flatten so the shadow hugs the card, not every inner view
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }

    /// Who the dashboard is about: the active child's avatar, name, grade, and
    /// three at-a-glance capsules echoing his trophy room.
    private var identityHeader: some View {
        let active = profiles.first(where: { $0.isActive })
        let known = (active?.facts ?? []).filter { $0.stage >= .fluency }.count
        return HStack(spacing: 14) {
            AvatarBadge(key: active?.avatarSymbol ?? avatars[0], size: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(active?.name ?? "Champion")
                    .font(Theme.Font.display(26)).foregroundStyle(Theme.Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let g = active?.grade, !g.isEmpty {
                    Text(g == "Pre-K" || g == "K" ? "Going into \(g)" : "Going into grade \(g)")
                        .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.inkSoft)
                }
            }
            Spacer(minLength: 12)
            statCapsule("star.fill", "\(active?.questStars ?? 0) stars", Theme.Color.accent)
            statCapsule("flame.fill", "\(active?.streakDays ?? 0)-day streak",
                        Color(red: 0.93, green: 0.42, blue: 0.13))
            statCapsule("bolt.fill", "\(known) of \(FactUniverse.count) facts", Theme.Color.primary)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 720)
        .cardSurface()
    }

    private func statCapsule(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(text).font(Theme.Font.label(14))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(tint.opacity(0.1), in: Capsule())
    }

    /// The year-of-birth gate as a small centered card over its own scrim.
    private var gateOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { showGate = false; pending = nil }
            ParentGateView(onPass: { showGate = false; pending?(); pending = nil },
                           onCancel: { showGate = false; pending = nil })
                .background(Theme.Color.surface,
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .compositingGroup()
                .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
        }
        .transition(.opacity)
    }

    // MARK: How progress works (parent explainer)

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { howOpen.toggle() }
            } label: {
                HStack {
                    sectionHeader("How progress works", "questionmark.circle.fill")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.inkSoft)
                        .rotationEffect(.degrees(howOpen ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if howOpen { explainRows }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
    }

    @ViewBuilder
    private var explainRows: some View {
            explainRow("star.fill",
                       "Every day is one QUEST: the app picks the facts for today's star and drills each one up its ladder (2 multiple-choice + 3 typed), mixed with review of everything learned so far. The quest ends when the star slams in — roughly 4–12 minutes, longer in bigger worlds.")
            explainRow("map.fill",
                       "Each world has \(activeGoal) stars ≈ one star per day. A hard day rolls over (\"star 80% charged — finish tomorrow\") with no penalty.")
            explainRow("flag.checkered",
                       "\(activeGoal) stars wake the BOSS: a timed round of that world's facts, pass at 85%, free retries. Beating it clears the world and reveals the next. 7 worlds = the trophy.")
            explainRow("flame.fill",
                       "The map flame lights when today's quest is done, and the number is his day streak. One missed day is forgiven; two in a row resets the streak. Extra play the same day continues to the next star. Mastery (for the certificate) still requires fast answers on 2 different days — that part can't be rushed.")
    }

    private func explainRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.primary).frame(width: 22)
            Text(text).font(Theme.Font.label(13)).foregroundStyle(Theme.Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Developer / testing

    @ViewBuilder
    private var developerCard: some View {
        if devUnlocked { devCardOpen } else { devCardLocked }
    }

    /// Collapsed state: the section exists but its contents (world names, session
    /// jumps) stay behind the gate so the child can't spoil or skip progression.
    private var devCardLocked: some View {
        Button { gated { devUnlocked = true } } label: {
            HStack {
                sectionHeader("Developer / Testing", "lock.fill")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Color.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Metric.pad)
        }
        .buttonStyle(.plain)
        .cardSurface()
    }

    private var devCardOpen: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Developer / Testing", "hammer.fill")

            Picker("World", selection: $testWorld) {
                ForEach(WorldCatalog.worlds, id: \.index) { w in
                    Text("World \(w.number): \(w.name)").tag(w.index)
                }
            }
            .pickerStyle(.menu).tint(Theme.Color.primary)

            Text("Jump into this world as:").font(Theme.Font.label(13)).foregroundStyle(Theme.Color.inkSoft)
            HStack(spacing: 10) {
                devBtn("Recognition", "rectangle.grid.2x2.fill") { testLaunch = WorldSelection(id: testWorld, testFormat: .recognition) }
                devBtn("Recall", "square.and.pencil") { testLaunch = WorldSelection(id: testWorld, testFormat: .recall) }
            }
            HStack(spacing: 10) {
                devBtn("Fluency (timed)", "bolt.fill") { testLaunch = WorldSelection(id: testWorld, testFormat: .fluency) }
                devBtn("Speed Round", "timer") { testLaunch = WorldSelection(id: testWorld, speed: true) }
            }
            devBtn("Boss Challenge", "flag.checkered") { testLaunch = WorldSelection(id: testWorld, boss: true) }

            Divider().padding(.vertical, 2)
            // Pacing knob: sockets per world. Progress is stored per-world now,
            // so changing this mid-game never loses stars — lowering it just
            // makes a full world boss-ready early.
            Stepper(value: Binding(get: { activeGoal },
                                   set: { service.setStarsPerWorldGoal($0) }),
                    in: 3...5) {
                Label("Stars per world: \(activeGoal)", systemImage: "star.fill")
                    .font(Theme.Font.label(14)).foregroundStyle(Theme.Color.ink)
            }
            Divider().padding(.vertical, 2)
            HStack(spacing: 10) {
                devBtn("Preview certificate", "trophy.fill") { showCert = true }
                devBtn("Unlock all worlds", "lock.open.fill") { service.applyDemoProgress(complete: false) }
            }
            devBtn("Master everything (100%)", "checkmark.seal.fill") { service.applyDemoProgress(complete: true) }

            Text("Tip: make a separate \"Test\" profile (Profiles → Add) so testing doesn't change your child's real progress.")
                .font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
    }

    private func devBtn(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(Theme.Font.label(14))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
        .buttonStyle(.bordered).tint(Theme.Color.primary)
    }

    // MARK: Profiles

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Players", "person.2.fill")
                Spacer()
                Button { gated { showAdd = true } } label: { Label("Add", systemImage: "plus.circle.fill") }
                    .font(Theme.Font.label(14))
            }
            ForEach(profiles) { p in profileRow(p) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
    }

    /// Management only — no stats here; the dashboard's identity header owns those.
    private func profileRow(_ p: Profile) -> some View {
        HStack(spacing: 10) {
            AvatarBadge(key: p.avatarSymbol, size: 32)
            Text(p.name).font(Theme.Font.label(16)).foregroundStyle(Theme.Color.ink)
                .lineLimit(1)
            if p.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.primary)
                    .accessibilityLabel("Active player")
            }
            Spacer()
            if !p.isActive {
                Button("Switch") { gated { service.switchTo(p) } }.font(Theme.Font.label(13)).buttonStyle(.bordered)
            }
            Menu {
                Button { gated { renameTarget = p; renameText = p.name } } label: { Label("Rename", systemImage: "pencil") }
                Button { gated { resetTarget = p } } label: { Label("Reset progress", systemImage: "arrow.counterclockwise") }
                Button { gated { startOverTarget = p } } label: { Label("Start over (redo onboarding)", systemImage: "arrow.uturn.backward") }
                if profiles.count > 1 {
                    Button(role: .destructive) { gated { deleteTarget = p } } label: { Label("Delete", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 22)).foregroundStyle(Theme.Color.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Settings (active profile)

    private var settingsCard: some View {
        let active = profiles.first(where: { $0.isActive })
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Settings", "gearshape.fill")
            if let a = active {
                Toggle("Sound effects", isOn: Binding(get: { a.soundOn }, set: { a.soundOn = $0; Feedback.soundEnabled = $0 }))
                Toggle("Speed Round unlocked", isOn: Binding(get: { a.speedRoundUnlocked }, set: { a.speedRoundUnlocked = $0 }))
                Toggle("Show timer during practice", isOn: Binding(get: { a.timingMode == .speed },
                                                                   set: { a.timingMode = $0 ? .speed : .gentle }))
                Text("Off keeps practice pressure-free (times are still tracked). The Speed Round always shows its timer.")
                    .font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
        .tint(Theme.Color.primary)
    }
}

/// The parent gate: "enter your year of birth" — accepts any year implying an
/// adult (18–100 years old).
struct ParentGateView: View {
    let onPass: () -> Void
    let onCancel: () -> Void

    @State private var entry = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Parents only").font(Theme.Font.display(24)).foregroundStyle(Theme.Color.ink)
            Text("Please enter your year of birth").font(Theme.Font.body()).foregroundStyle(Theme.Color.inkSoft)
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    Text(i < entry.count ? String(Array(entry)[i]) : "")
                        .font(Theme.Font.number(30)).foregroundStyle(Theme.Color.ink)
                        .frame(width: 52, height: 62)
                        .background(Theme.Color.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(i == entry.count ? Theme.Color.primary : .clear, lineWidth: 2))
                }
            }
            if wrong { Text("Not quite — try again").font(Theme.Font.label()).foregroundStyle(Theme.Color.gentle) }
            NumberPadView(enterEnabled: entry.count == 4,
                          onDigit: { d in if entry.count < 4 { entry.append(String(d)) } },
                          onDelete: { _ = entry.popLast() },
                          onEnter: check,
                          keyTint: Theme.Color.primary)
            Button("Cancel", action: onCancel).font(Theme.Font.label()).padding(.top, 4)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 460)
    }

    private func check() {
        let currentYear = Calendar.current.component(.year, from: .now)
        if let y = Int(entry), ((currentYear - 100)...(currentYear - 18)).contains(y) {
            onPass()
        } else {
            wrong = true; entry = ""
        }
    }
}
