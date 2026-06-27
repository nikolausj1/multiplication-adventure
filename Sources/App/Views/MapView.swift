import SwiftUI
import SwiftData

/// The adventure map — the home/hub. A winding trail of 7 world nodes fitted to one
/// landscape screen; locked worlds are fogged, the current world pulses. Tapping an
/// unlocked node starts a themed session. The gear opens the parent area.
struct MapView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var sessionWorld: WorldSelection?
    @State private var showParent = false
    @State private var speedRound = false

    private var profile: Profile? { activeProfiles.first }
    private var snapshots: [FactSnapshot] { (profile?.facts ?? []).map(\.snapshot) }
    private var stats: [WorldStat] { WorldProgress.stats(snapshots: snapshots) }
    private var currentIndex: Int { WorldProgress.currentIndex(snapshots: snapshots) }

    /// Fractional positions of each world node, forming a left→right winding trail.
    private let pts: [CGPoint] = [
        CGPoint(x: 0.09, y: 0.74), CGPoint(x: 0.22, y: 0.44), CGPoint(x: 0.35, y: 0.70),
        CGPoint(x: 0.49, y: 0.42), CGPoint(x: 0.63, y: 0.68), CGPoint(x: 0.78, y: 0.42),
        CGPoint(x: 0.91, y: 0.66),
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
            VStack { header; Spacer() }
        }
        .fullScreenCover(item: $sessionWorld) { sel in
            SessionView(worldIndex: sel.id, speedRound: speedRound)
                .environment(\.worldTheme, .forWorld(sel.id))
        }
        .sheet(isPresented: $showParent) { ParentAreaView() }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autostartSession") { sessionWorld = WorldSelection(id: currentIndex) }
            if args.contains("-autostartParent") { showParent = true }
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
            HStack(spacing: 12) {
                Image(systemName: profile?.avatarSymbol ?? "figure.hiking")
                    .font(.system(size: 24)).foregroundStyle(Theme.Color.primary)
                    .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile?.name ?? "Player").font(Theme.Font.display(17)).foregroundStyle(Theme.Color.ink)
                    Text("\(profile?.totalXP ?? 0) XP").font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
                }
            }
            .padding(8).padding(.trailing, 8).scrimCard()
            Spacer()
            Text("Multiplication Adventure")
                .font(Theme.Font.display(20)).foregroundStyle(.white).shadow(radius: 3)
                .padding(.top, 10)
            Spacer()
            if let p = profile, p.streakDays > 0 {
                Label("\(p.streakDays)", systemImage: "flame.fill")
                    .font(Theme.Font.number(17)).foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, 12).padding(.vertical, 9).scrimCard()
            }
            Button { showParent = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 20))
                    .foregroundStyle(Theme.Color.inkSoft)
                    .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
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
        VStack(spacing: 5) {
            Button {
                guard unlocked else { return }
                speedRound = false
                sessionWorld = WorldSelection(id: world.index)
            } label: {
                ZStack {
                    if unlocked {
                        WorldNodeBadge(theme: .forWorld(world.index))
                            .frame(width: 104, height: 104).clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 4))
                            .shadow(color: .black.opacity(0.4), radius: 7, y: 3)
                    } else {
                        lockedNode
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
            .buttonStyle(PopButtonStyle()).disabled(!unlocked)

            Text(unlocked ? world.name : "???")
                .font(Theme.Font.label(13)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.5)))
            if isCurrent {
                Text("TAP TO PLAY").font(Theme.Font.label(10)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Color.primary))
            }
        }
        .frame(width: 150)
    }

    private var lockedNode: some View {
        ZStack {
            if Art.exists("node_locked") {
                Image("node_locked").resizable().scaledToFit().frame(width: 104, height: 104)
            } else {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 96, height: 96)
            }
            Image(systemName: "questionmark").font(.system(size: 32, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
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

/// Wrapper so `fullScreenCover(item:)` can carry a world index.
struct WorldSelection: Identifiable { let id: Int }
