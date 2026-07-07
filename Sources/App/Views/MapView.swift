import SwiftUI
import SwiftData

/// The adventure map — the home/hub. A winding trail of 7 world nodes fitted to one
/// landscape screen; locked worlds are fogged, the current world pulses. Tapping an
/// unlocked node starts a themed session. The gear opens the parent area.
struct MapView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var sessionWorld: WorldSelection?
    @State private var showParent = false
    @State private var showProfile = false
    @State private var showStreak = false
    @State private var showTimesTable = false
    @State private var showCertificate = false

    // Locked-node tap response + the fog-lift reveal when a new world opens.
    @State private var shakeTarget: Int?
    @State private var shakePhase: CGFloat = 0
    @State private var hintNode: Int?
    @State private var revealWorld: Int?
    @State private var baselineCurrent = 0

    private var profile: Profile? { activeProfiles.first }
    private var snapshots: [FactSnapshot] { (profile?.facts ?? []).map(\.snapshot) }
    private var clearedSet: Set<Int> { profile?.clearedWorlds ?? [] }
    private var currentIndex: Int { profile?.currentWorldIndex ?? 0 }
    /// The anytime Speed Round is a parent-enabled extra; the boss challenge is
    /// the built-in timed moment.
    private var canSpeedRound: Bool { profile?.speedRoundUnlocked ?? false }
    private var isComplete: Bool { (profile?.masteredCount ?? 0) == FactUniverse.count }

    /// Fractional positions of each world node, forming a left→right winding trail,
    /// vertically centered in the space between the title banner and screen bottom.
    private let pts: [CGPoint] = [
        CGPoint(x: 0.09, y: 0.82), CGPoint(x: 0.22, y: 0.56), CGPoint(x: 0.35, y: 0.80),
        CGPoint(x: 0.49, y: 0.55), CGPoint(x: 0.63, y: 0.78), CGPoint(x: 0.78, y: 0.55),
        CGPoint(x: 0.91, y: 0.76),
    ]

    var body: some View {
        ZStack {
            mapBackdrop
            GeometryReader { geo in
                let scaled = pts.map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
                ZStack {
                    TrailPath(points: scaled)
                        .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 14]))
                        .foregroundStyle(.white.opacity(0.55))
                    ForEach(WorldCatalog.worlds, id: \.index) { world in
                        nodeView(world)
                            .position(scaled[world.index])
                    }
                }
            }
            DriftingMist().ignoresSafeArea()
            // The endgame reveals itself only after the Storm Titan falls: master
            // every fact to claim the trophy certificate.
            if clearedSet.count == WorldCatalog.count, !isComplete {
                VStack { Spacer(); masterQuestBar }
            }
            // Full-bleed title banner: painted sky fades into the map's fog.
            if Art.exists("map_banner") {
                VStack(spacing: 0) {
                    Image("map_banner").resizable().scaledToFit()
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: [.top, .horizontal])
                .allowsHitTesting(false)
            }
            VStack { header; Spacer() }
        }
        .fullScreenCover(item: $sessionWorld, onDismiss: checkUnlockReveal) { sel in
            SessionView(worldIndex: sel.id, speedRound: sel.speed, boss: sel.boss)
                .environment(\.worldTheme, .forWorld(sel.id))
        }
        .fullScreenCover(isPresented: $showParent, onDismiss: { baselineCurrent = currentIndex }) { ParentAreaView() }
        // In-hierarchy overlay, NOT a cover: the cover's hosting layer fights
        // the keyboard (see PlayerProfileView) — here the GUI stays frozen.
        // The map subtree has no text input of its own, so it ignores the
        // keyboard wholesale; without this the inset still squeezes the card.
        .overlay {
            if showProfile {
                PlayerProfileView(onClose: {
                    withAnimation(.easeOut(duration: 0.2)) { showProfile = false }
                })
                .transition(.opacity)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showStreak) { StreakView() }
        .fullScreenCover(isPresented: $showTimesTable) { TimesTableView() }
        .sheet(isPresented: $showCertificate) { CertificateView(name: profile?.name ?? "Champion") }
        .onAppear {
            baselineCurrent = currentIndex
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autostartSession") { sessionWorld = WorldSelection(id: currentIndex) }
            if args.contains("-autostartParent") { showParent = true }
            if args.contains("-autostartProfile") { showProfile = true }
            if args.contains("-autostartStreak") { showStreak = true }
            if args.contains("-autostartTimesTable") { showTimesTable = true }
            if args.contains("-autostartCertificate") { showCertificate = true }
            if args.contains("-autostartSpeed") { sessionWorld = WorldSelection(id: currentIndex, speed: true) }
            if args.contains("-autostartBoss") { sessionWorld = WorldSelection(id: currentIndex, boss: true) }
            // Demo: play the fog-lift reveal on the current node (pair with -demoProgress).
            if args.contains("-demoReveal") { revealWorld = currentIndex }
        }
    }

    // MARK: Backdrop

    private var mapBackdrop: some View {
        ZStack {
            if Art.exists("map_bg") {
                // Contained fill (see WorldBackdrop): keeps the image's overflow
                // out of layout so 4:3 screens don't push siblings off-screen.
                Color.clear
                    .overlay(Image("map_bg").resizable().scaledToFill())
                    .clipped()
            } else {
                LinearGradient(colors: [Theme.Color.bg, Theme.Color.primary.opacity(0.25)],
                               startPoint: .top, endPoint: .bottom)
            }
            Color.black.opacity(0.10)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            // Player chip: dark glass to match the session plates. Tapping it
            // opens the kid's trophy-room profile.
            Button { withAnimation(.easeOut(duration: 0.2)) { showProfile = true } } label: {
                HStack(spacing: 10) {
                    AvatarBadge(key: profile?.avatarSymbol ?? "avatar1", size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile?.name ?? "Player").font(Theme.Font.display(16)).foregroundStyle(.white)
                        HStack(spacing: 3) {
                            // Gem, not star: stars are world progress, XP is treasure.
                            Image(systemName: "diamond.fill").font(.system(size: 9))
                                .foregroundStyle(Theme.Color.accent)
                            Text("\(profile?.totalXP ?? 0) XP")
                                .font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.vertical, 7).padding(.horizontal, 9).padding(.trailing, 7)
                .darkPlate(corner: 27)
            }
            .buttonStyle(PopButtonStyle())
            .accessibilityLabel("My profile")
            Spacer()
            // Title lives in the full-bleed banner; fall back to the floating
            // logo or text when banner art is absent.
            if !Art.exists("map_banner") {
                if Art.exists("map_header") {
                    Image("map_header").resizable().scaledToFit()
                        .frame(height: 118)
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
                } else {
                    Text("Multiplication Adventure")
                        .font(Theme.Font.display(20)).foregroundStyle(.white).shadow(radius: 3)
                        .padding(.top, 10)
                }
                Spacer()
            }
            if isComplete {
                Button { showCertificate = true } label: {
                    Image(systemName: "trophy.fill").font(.system(size: 19))
                        .foregroundStyle(Theme.Color.accent)
                        .frame(width: 44, height: 44).darkPlate(corner: 22)
                }
                .accessibilityLabel("Certificate")
            }
            if canSpeedRound {
                Button { sessionWorld = WorldSelection(id: currentIndex, speed: true) } label: {
                    Label("Speed", systemImage: "timer").font(Theme.Font.label(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
                }
            }
            // Times-table reference — a lookup chart, deliberately map-only so
            // it's never available mid-quest.
            Button { showTimesTable = true } label: {
                Image(systemName: "tablecells.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44).darkPlate(corner: 22)
            }
            .buttonStyle(PopButtonStyle())
            .accessibilityLabel("Times tables")
            if let p = profile {
                // The daily flame: lit = today's quest done; dim = not yet today.
                // Tapping opens the streak calendar.
                let practicedToday = p.lastPracticeDate.map { Calendar.current.isDateInToday($0) } ?? false
                Button { showStreak = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(practicedToday ? Theme.Color.accent : Color.white.opacity(0.3))
                        if p.streakDays > 0 {
                            Text("\(p.streakDays)").font(Theme.Font.number(16))
                                .foregroundStyle(practicedToday ? .white : .white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
                }
                .buttonStyle(PopButtonStyle())
                .accessibilityLabel(practicedToday
                    ? "Streak \(p.streakDays) days, practiced today"
                    : "Not practiced yet today")
            }
            Button { showParent = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 19))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44).darkPlate(corner: 22)
            }
            .accessibilityLabel("Parent area")
        }
        .padding(.horizontal, Theme.Metric.pad).padding(.top, 10)
    }

    // MARK: Node

    @ViewBuilder
    private func nodeView(_ world: World) -> some View {
        let unlocked = world.index <= currentIndex
        let cleared = clearedSet.contains(world.index)
        let isCurrent = world.index == currentIndex
        let goal = profile?.starsPerWorldGoal ?? WorldCatalog.starsPerWorld
        let starsHere = isCurrent ? (profile?.starsInCurrentWorld ?? 0) : (cleared ? goal : 0)
        // All sockets filled but boss unbeaten → the node IS the boss fight.
        let bossReady = isCurrent && !cleared && starsHere == goal
        VStack(spacing: 5) {
            Button {
                if bossReady { sessionWorld = WorldSelection(id: world.index, boss: true) }
                else if unlocked { sessionWorld = WorldSelection(id: world.index) }
                else { nudgeLocked(world.index) }
            } label: {
                ZStack {
                    if unlocked {
                        if world.index == revealWorld {
                            UnlockRevealNode(index: world.index) { revealWorld = nil }
                        } else {
                            UnlockedBadge(index: world.index)
                        }
                    } else {
                        LockedNodeView()
                    }
                    if isCurrent { PulsingRing() }
                    if cleared {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 26))
                            .foregroundStyle(Theme.Color.correct)
                            .background(Circle().fill(.white).frame(width: 24, height: 24))
                            .offset(x: 38, y: -38)
                    }
                }
            }
            .buttonStyle(PopButtonStyle())
            .modifier(Shake(animatableData: world.index == shakeTarget ? shakePhase : 0))

            if unlocked {
                // Star sockets — one star per completed quest; cleared worlds
                // always wear the full set.
                WorldStars(filled: starsHere, total: goal, size: 19, spacing: 4)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .padding(.top, 2)
                Text(world.name)
                    .font(Theme.Font.label(13)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.5)))
            }
            if bossReady {
                Label("BOSS CHALLENGE!", systemImage: "flag.checkered")
                    .font(Theme.Font.label(10)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(
                        LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.2),
                                                Color(red: 0.6, green: 0.1, blue: 0.15)],
                                       startPoint: .top, endPoint: .bottom)))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            } else if isCurrent, !cleared {
                let remaining = goal - starsHere
                let resumable = (profile?.pausedQuestDate).map {
                    Calendar.current.isDateInToday($0)
                } ?? false
                Text(resumable ? "CONTINUE QUEST!"
                     : starsHere > 0 && remaining > 0
                     ? "\(remaining) STAR\(remaining == 1 ? "" : "S") TO THE BOSS!" : "TAP TO PLAY")
                    .font(Theme.Font.label(10)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Color.primary))
            }
            if hintNode == world.index {
                Text("Clear \(WorldCatalog.worlds[safe: currentIndex]?.name ?? "the current world") first!")
                    .font(Theme.Font.label(11)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Color.primary))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(width: 150)
        .animation(Theme.Motion.snappy, value: hintNode)
    }

    private var masterQuestBar: some View {
        let mastered = profile?.masteredCount ?? 0
        let total = FactUniverse.count
        return HStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.system(size: 22))
                .foregroundStyle(Theme.Color.accent)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("MASTER QUEST").font(Theme.Font.label(13)).tracking(2)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(mastered)/\(total)").font(Theme.Font.number(15))
                        .foregroundStyle(Theme.Color.accent)
                        .contentTransition(.numericText(value: Double(mastered)))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.4))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.35),
                                                          Color(red: 0.95, green: 0.6, blue: 0.1)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: geo.size.width * CGFloat(mastered) / CGFloat(total))
                        Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .frame(maxWidth: 500)
        .darkPlate()
        .padding(.bottom, 16)
        .accessibilityLabel("Master Quest: \(mastered) of \(total) facts mastered")
    }

    /// A tap on a fogged node shouldn't feel broken: wiggle it and say what unlocks it.
    private func nudgeLocked(_ index: Int) {
        Feedback.fire(.keyTap)
        hintNode = index
        if !reduceMotion {
            shakeTarget = index
            withAnimation(.easeInOut(duration: 0.45)) { shakePhase += 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if hintNode == index { hintNode = nil }
        }
    }

    /// Called when a session cover closes: if the trail advanced, run the fog-lift
    /// reveal on the newly reachable world.
    private func checkUnlockReveal() {
        let now = currentIndex
        if now > baselineCurrent, !clearedSet.contains(now) {
            revealWorld = now
        }
        baselineCurrent = now
    }
}

/// The standard unlocked world badge on the map.
private struct UnlockedBadge: View {
    let index: Int
    var body: some View {
        WorldNodeBadge(theme: .forWorld(index))
            .frame(width: 104, height: 104).clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 4))
            .shadow(color: .black.opacity(0.4), radius: 7, y: 3)
    }
}

/// Fogged, unknown world node. The smoke art deliberately billows beyond the
/// 104pt node footprint, so it renders larger without shifting the node's center.
private struct LockedNodeView: View {
    var body: some View {
        ZStack {
            if Art.exists("node_locked") {
                Image("node_locked").resizable().scaledToFit().frame(width: 138, height: 138)
            } else {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 96, height: 96)
            }
            Image(systemName: "questionmark").font(.system(size: 32, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.6), radius: 3)
        }
        .frame(width: 104, height: 104)   // layout footprint stays the node size
    }
}

/// The fog-lift moment: the locked node swells and dissolves while the world badge
/// springs in underneath. Plays the unlock sound; respects Reduced Motion.
private struct UnlockRevealNode: View {
    let index: Int
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            UnlockedBadge(index: index)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (revealed ? 1 : 0.35))
            LockedNodeView()
                .opacity(revealed ? 0 : 1)
                .scaleEffect(reduceMotion || !revealed ? 1 : 1.5)
                .blur(radius: reduceMotion || !revealed ? 0 : 14)
            // The fog physically billows away as the world appears underneath.
            ParticleBurst(kind: .smoke, colors: [.white, Color(white: 0.82)],
                          seed: UInt64(index) &* 7919 &+ 5)
                .frame(width: 260, height: 260)
        }
        .onAppear {
            Feedback.fire(.levelUp)
            withAnimation(reduceMotion ? Theme.Motion.quick
                          : .spring(response: 0.7, dampingFraction: 0.55).delay(0.45)) {
                revealed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { onDone() }
        }
    }
}


/// A dashed trail connecting the node positions.
private struct TrailPath: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        return p
    }
}

/// A pulsing ring marking the current world (respects Reduced Motion).
private struct PulsingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    var body: some View {
        Circle()
            .strokeBorder(Theme.Color.accent, lineWidth: 5)
            .frame(width: 124, height: 124)
            .scaleEffect(animate && !reduceMotion ? 1.14 : 1.0)
            .opacity(animate && !reduceMotion ? 0.2 : 0.9)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { animate = true }
            }
    }
}

/// Wrapper so `fullScreenCover(item:)` can carry a world index + how to start it.
/// `boss` runs the world's boss challenge; `speed` a Speed Round; `testFormat`
/// forces a question format (dev/testing).
struct WorldSelection: Identifiable {
    let id: Int
    var speed: Bool = false
    var boss: Bool = false
    var testFormat: MasteryStage? = nil
}
