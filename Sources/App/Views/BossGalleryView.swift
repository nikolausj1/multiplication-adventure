import SwiftUI

/// Developer-only preview: flips through all 7 boss guardians using the REAL
/// `BossPanel` view over the world's own backdrop, so the video/still swap and
/// the alpha cutout can be judged against real art without playing the game.
/// Reached from Parent Area → Developer / Testing (behind the parent gate) so
/// the child can't stumble into boss spoilers.
struct BossGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    private var compact: Bool { vSize == .compact }

    @State private var worldIndex: Int
    @State private var hits = 0
    @State private var lastHitCritical = false

    /// Launches the REAL boss session for the world currently on screen.
    /// Defaulted so existing call sites and previews keep compiling.
    var onPlayBoss: (Int) -> Void = { _ in }

    init(initialWorldIndex: Int = 0, onPlayBoss: @escaping (Int) -> Void = { _ in }) {
        _worldIndex = State(initialValue: initialWorldIndex)
        self.onPlayBoss = onPlayBoss
    }

    private let hpTotal = 5
    private var theme: WorldTheme { .forWorld(worldIndex) }
    private var world: World { theme.world }
    private var isVideo: Bool { Art.videoURL(theme.bossVideo) != nil }

    var body: some View {
        ZStack {
            WorldBackdrop(theme: theme)

            VStack(spacing: compact ? 8 : 18) {
                header
                HStack(spacing: compact ? 10 : 26) {
                    navButton("chevron.left", label: "Previous world") { step(-1) }
                    BossPanel(theme: theme, hits: hits, hpTotal: hpTotal, lastHitCritical: lastHitCritical)
                        .frame(maxWidth: compact ? 280 : 660, maxHeight: compact ? 210 : 580)
                    navButton("chevron.right", label: "Next world") { step(1) }
                }
                playBossButton
                Spacer(minLength: 4)
                controls
            }
            .padding(.horizontal, compact ? 14 : Theme.Metric.pad)
            .padding(.vertical, compact ? 10 : Theme.Metric.pad)
        }
        .environment(\.worldTheme, theme)
        .overlay(alignment: .topLeading) { ModalCloseButton { dismiss() }.padding(14) }
        .onChange(of: worldIndex) { _, _ in resetHits() }
    }

    // MARK: Header — world picker + the unmissable VIDEO/STILL badge

    private var header: some View {
        VStack(spacing: 6) {
            Picker("World", selection: $worldIndex) {
                ForEach(WorldCatalog.worlds, id: \.index) { w in
                    Text("World \(w.number): \(w.name)").tag(w.index)
                }
            }
            .pickerStyle(.menu).tint(.white)

            Text("World \(world.number) · \(world.name) — \(world.bossName)")
                .font(Theme.Font.label(compact ? 13 : 16)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 3, y: 2)

            // The main thing this screen exists to check — big, high-contrast,
            // impossible to miss at a glance.
            Text(isVideo ? "VIDEO" : "STILL")
                .font(Theme.Font.display(compact ? 18 : 26)).tracking(3)
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 14 : 20).padding(.vertical, compact ? 6 : 10)
                .background(Capsule().fill(isVideo ? Theme.Color.correct : Theme.Color.inkSoft))
                .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        }
        .padding(.top, compact ? 4 : 10)
    }

    // MARK: Play Boss Fight — the primary action, distinct from the preview pokes below

    private var playBossButton: some View {
        Button { onPlayBoss(worldIndex) } label: {
            Label("Play Boss Fight", systemImage: "flag.checkered")
                .font(Theme.Font.label(compact ? 16 : 21))
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 12 : 18)
        }
        .buttonStyle(ChunkyKeyStyle(base: Theme.Color.accent, deep: Theme.Color.accent.shaded(by: -0.4)))
        .frame(maxWidth: compact ? 320 : 460)
        .accessibilityHint("Launches the real boss fight for this world")
    }

    private func navButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: compact ? 26 : 36, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: compact ? 56 : 76, height: compact ? 56 : 76)
        }
        .buttonStyle(ChunkyKeyStyle(base: Theme.Color.primary, deep: Theme.Color.primary.shaded(by: -0.4)))
        .accessibilityLabel(label)
    }

    private func step(_ delta: Int) {
        worldIndex = (worldIndex + delta + WorldCatalog.count) % WorldCatalog.count
    }

    // MARK: Controls — chunky, one-handed, iPad-sized targets

    private var controls: some View {
        VStack(spacing: compact ? 6 : 12) {
            HStack(spacing: compact ? 10 : 16) {
                controlBtn("Hit", "bolt.fill", tint: Theme.Color.primary) {
                    lastHitCritical = false
                    hits = min(hits + 1, hpTotal)
                }
                controlBtn("Critical Hit", "sparkles", tint: Theme.Color.accent) {
                    lastHitCritical = true
                    hits = min(hits + 1, hpTotal)
                }
            }
            HStack(spacing: compact ? 10 : 16) {
                controlBtn("Defeat", "flag.checkered", tint: Theme.Color.correct) {
                    lastHitCritical = false
                    hits = hpTotal
                }
                controlBtn("Reset", "arrow.counterclockwise", tint: Theme.Color.gentle) {
                    resetHits()
                }
            }
        }
        .padding(.bottom, compact ? 4 : 10)
    }

    private func resetHits() {
        hits = 0
        lastHitCritical = false
    }

    private func controlBtn(_ title: String, _ icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.Font.label(compact ? 15 : 19))
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 12 : 20)
        }
        .buttonStyle(ChunkyKeyStyle(base: tint, deep: tint.shaded(by: -0.4)))
        .frame(minWidth: compact ? 140 : 220)
    }
}
