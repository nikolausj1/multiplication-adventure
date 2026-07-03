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
    @State private var showCertificate = false

    // Locked-node tap response + the fog-lift reveal when a new world opens.
    @State private var shakeTarget: Int?
    @State private var shakePhase: CGFloat = 0
    @State private var hintNode: Int?
    @State private var revealWorld: Int?
    @State private var baselineCurrent = 0

    private var profile: Profile? { activeProfiles.first }
    private var snapshots: [FactSnapshot] { (profile?.facts ?? []).map(\.snapshot) }
    private var stats: [WorldStat] { WorldProgress.stats(snapshots: snapshots) }
    private var currentIndex: Int { WorldProgress.currentIndex(snapshots: snapshots) }
    private var fluentPlus: Int { snapshots.filter { $0.stage >= .fluency }.count }
    private var canSpeedRound: Bool { fluentPlus >= 10 || (profile?.speedRoundUnlocked ?? false) }
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
            SessionView(worldIndex: sel.id, speedRound: sel.speed)
                .environment(\.worldTheme, .forWorld(sel.id))
        }
        .sheet(isPresented: $showParent, onDismiss: { baselineCurrent = currentIndex }) { ParentAreaView() }
        .sheet(isPresented: $showCertificate) { CertificateView(name: profile?.name ?? "Champion") }
        .onAppear {
            baselineCurrent = currentIndex
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autostartSession") { sessionWorld = WorldSelection(id: currentIndex) }
            if args.contains("-autostartParent") { showParent = true }
            if args.contains("-autostartCertificate") { showCertificate = true }
            if args.contains("-autostartSpeed") { sessionWorld = WorldSelection(id: currentIndex, speed: true) }
            // Demo: play the fog-lift reveal on the current node (pair with -demoProgress).
            if args.contains("-demoReveal") { revealWorld = currentIndex }
        }
    }

    // MARK: Backdrop

    private var mapBackdrop: some View {
        ZStack {
            if Art.exists("map_bg") {
                Image("map_bg").resizable().scaledToFill()
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
            // Player chip: dark glass to match the session plates.
            HStack(spacing: 10) {
                Image(systemName: profile?.avatarSymbol ?? "figure.hiking")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(LinearGradient(colors: [Theme.Color.primary.shaded(by: 0.2),
                                                              Theme.Color.primary.shaded(by: -0.2)],
                                                     startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile?.name ?? "Player").font(Theme.Font.display(16)).foregroundStyle(.white)
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 10))
                            .foregroundStyle(Theme.Color.accent)
                        Text("\(profile?.totalXP ?? 0) XP")
                            .font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(.vertical, 7).padding(.horizontal, 9).padding(.trailing, 7)
            .darkPlate(corner: 27)
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
            if let p = profile, p.streakDays > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.Color.accent)
                    Text("\(p.streakDays)").font(Theme.Font.number(16)).foregroundStyle(.white)
                }
                .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
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
        let cleared = stats[safe: world.index]?.cleared ?? false
        let isCurrent = world.index == currentIndex
        let stat = stats[safe: world.index]
        VStack(spacing: 5) {
            Button {
                if unlocked { sessionWorld = WorldSelection(id: world.index) }
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
                    // Progress toward clearing the current world — the "almost there" cue.
                    if isCurrent, !cleared, let s = stat, s.total > 0, s.fluentPlus > 0 {
                        Circle().trim(from: 0, to: CGFloat(s.fluentPlus) / CGFloat(s.total))
                            .stroke(Theme.Color.correct, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 104, height: 104)
                            .shadow(color: .black.opacity(0.35), radius: 2)
                    }
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

            Text(unlocked ? world.name : "???")
                .font(Theme.Font.label(13)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.5)))
            if isCurrent, !cleared {
                let remaining = stat.map { $0.total - $0.fluentPlus } ?? 0
                let started = (stat?.fluentPlus ?? 0) > 0
                Text(started && remaining > 0 ? "\(remaining) TO GO!" : "TAP TO PLAY")
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
        if now > baselineCurrent, !(stats[safe: now]?.cleared ?? false) {
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

/// Horizontal shake for "not yet" taps; integer phases land at zero offset.
private struct Shake: GeometryEffect {
    var travel: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2), y: 0))
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
/// `testFormat` forces a specific question format (dev/testing); `speed` runs a Speed Round.
struct WorldSelection: Identifiable {
    let id: Int
    var speed: Bool = false
    var testFormat: MasteryStage? = nil
}
