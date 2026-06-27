import SwiftUI
import SwiftData

/// The adventure map — the home/hub. A serpentine path of 7 world nodes over the
/// map art; locked worlds are fogged, the current world pulses. Tapping an unlocked
/// node starts a themed session. The gear opens the parent area.
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

    var body: some View {
        ZStack(alignment: .top) {
            mapBackdrop
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 96)            // room for the header
                    path
                    Color.clear.frame(height: 40)
                }
            }
            header
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
            Color.black.opacity(0.12)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 12) {
                Image(systemName: profile?.avatarSymbol ?? "figure.hiking")
                    .font(.system(size: 26)).foregroundStyle(Theme.Color.primary)
                    .frame(width: 46, height: 46).background(.ultraThinMaterial, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile?.name ?? "Player").font(Theme.Font.display(18))
                        .foregroundStyle(Theme.Color.ink)
                    Text("\(profile?.totalXP ?? 0) XP").font(Theme.Font.label(13))
                        .foregroundStyle(Theme.Color.inkSoft)
                }
            }
            .padding(8).padding(.trailing, 8).scrimCard()

            Spacer()

            if let p = profile, p.streakDays > 0 {
                Label("\(p.streakDays)", systemImage: "flame.fill")
                    .font(Theme.Font.number(18)).foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, 12).padding(.vertical, 10).scrimCard()
            }
            Button { showParent = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 22))
                    .foregroundStyle(Theme.Color.inkSoft)
                    .frame(width: 46, height: 46).background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Parent area")
        }
        .padding(.horizontal, Theme.Metric.pad)
        .padding(.top, 12)
    }

    // MARK: Serpentine path of nodes

    private var path: some View {
        VStack(spacing: 8) {
            ForEach(WorldCatalog.worlds, id: \.index) { world in
                nodeRow(world)
            }
            finishFlag
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private func nodeRow(_ world: World) -> some View {
        let unlocked = world.index <= currentIndex
        let cleared = stats[safe: world.index]?.cleared ?? false
        let isCurrent = world.index == currentIndex
        HStack {
            if world.index.isMultiple(of: 2) { node(world, unlocked: unlocked, cleared: cleared, isCurrent: isCurrent); Spacer() }
            else { Spacer(); node(world, unlocked: unlocked, cleared: cleared, isCurrent: isCurrent) }
        }
    }

    private func node(_ world: World, unlocked: Bool, cleared: Bool, isCurrent: Bool) -> some View {
        VStack(spacing: 6) {
            Button {
                guard unlocked else { return }
                speedRound = false
                sessionWorld = WorldSelection(id: world.index)
            } label: {
                ZStack {
                    if unlocked {
                        WorldNodeBadge(theme: .forWorld(world.index))
                            .frame(width: 132, height: 132)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 4))
                            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    } else {
                        lockedNode
                    }
                    if isCurrent { PulsingRing() }
                    if cleared {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 30)).foregroundStyle(Theme.Color.correct)
                            .background(Circle().fill(.white).frame(width: 30, height: 30))
                            .offset(x: 48, y: -48)
                    }
                }
            }
            .buttonStyle(PopButtonStyle())
            .disabled(!unlocked)

            Text(unlocked ? world.name : "???")
                .font(Theme.Font.label(15)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.45)))
            if isCurrent {
                Text("TAP TO PLAY").font(Theme.Font.label(11)).tracking(1.2)
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Color.primary))
            }
        }
        .frame(width: 180)
    }

    private var lockedNode: some View {
        ZStack {
            if Art.exists("node_locked") {
                Image("node_locked").resizable().scaledToFit().frame(width: 132, height: 132)
            } else {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 120, height: 120)
            }
            Image(systemName: "questionmark").font(.system(size: 40, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var finishFlag: some View {
        VStack(spacing: 6) {
            Image(systemName: WorldProgress.clearedCount(snapshots: snapshots) == WorldCatalog.count
                  ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 44)).foregroundStyle(Theme.Color.accent)
                .padding(20).background(.ultraThinMaterial, in: Circle())
            Text("The Summit").font(Theme.Font.label(14)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.45)))
        }
        .padding(.top, 8)
    }
}

/// A pulsing ring marking the current world (respects Reduced Motion).
private struct PulsingRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    var body: some View {
        Circle()
            .strokeBorder(Theme.Color.accent, lineWidth: 5)
            .frame(width: 150, height: 150)
            .scaleEffect(animate && !reduceMotion ? 1.12 : 1.0)
            .opacity(animate && !reduceMotion ? 0.2 : 0.9)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

/// Wrapper so `fullScreenCover(item:)` can carry a world index without a retroactive
/// Identifiable conformance on Int.
struct WorldSelection: Identifiable { let id: Int }
