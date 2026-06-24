import SwiftUI
import SwiftData

/// Home. Per §3/§6 the child never picks what to study — one big button starts a
/// session that already knows what comes next. The dashboard is shared transparently.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var facts: [Fact]
    @Query private var profiles: [Profile]

    @State private var showSession = false
    @State private var showDashboard = false
    @State private var speedRound = false

    private var profile: Profile? { profiles.first }
    private var masteredCount: Int { facts.filter { $0.stage == .mastered }.count }
    private var rank: Rank { RankLadder.rank(forMasteredCount: masteredCount) }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 28) {
                header
                Spacer()
                rankBadge
                masteryReadout
                Spacer()
                buttons
            }
            .padding(Theme.Metric.pad)
            .frame(maxWidth: 620)
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView(speedRound: speedRound)
        }
        .sheet(isPresented: $showDashboard) { DashboardView() }
        .onAppear {
            // UI-verification hook: launch with -autostartSession to open straight into a session.
            if ProcessInfo.processInfo.arguments.contains("-autostartSession") { showSession = true }
            if ProcessInfo.processInfo.arguments.contains("-autostartDashboard") { showDashboard = true }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Level Up Math").font(Theme.Font.display(30)).foregroundStyle(Theme.Color.ink)
                if let p = profile {
                    Text("\(p.name) · \(p.totalXP) XP")
                        .font(Theme.Font.label()).foregroundStyle(Theme.Color.inkSoft)
                }
            }
            Spacer()
            if let p = profile, p.streakDays > 0 {
                Label("\(p.streakDays)", systemImage: "flame.fill")
                    .font(Theme.Font.number(20))
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .cardSurface()
            }
        }
    }

    private var rankBadge: some View {
        VStack(spacing: 12) {
            Image(systemName: profile?.avatarSymbol ?? "bolt.circle.fill")
                .font(.system(size: 86))
                .foregroundStyle(Theme.Color.primary)
                .symbolRenderingMode(.hierarchical)
            Text(rank.name).font(Theme.Font.display(34)).foregroundStyle(Theme.Color.ink)
        }
    }

    private var masteryReadout: some View {
        VStack(spacing: 10) {
            let pct = Int((Double(masteredCount) / Double(FactUniverse.count)) * 100)
            Text("\(pct)% mastered").font(Theme.Font.number(22)).foregroundStyle(Theme.Color.ink)
            ProgressView(value: Double(masteredCount), total: Double(FactUniverse.count))
                .tint(Theme.Color.correct)
                .scaleEffect(x: 1, y: 2.4, anchor: .center)
                .frame(maxWidth: 360)
            if let next = RankLadder.next(afterMasteredCount: masteredCount) {
                Text("\(next.remaining) more to \(next.rank.name)")
                    .font(Theme.Font.label()).foregroundStyle(Theme.Color.inkSoft)
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            Button { speedRound = false; showSession = true } label: {
                Label("Practice", systemImage: "play.fill")
                    .font(Theme.Font.display(24)).frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent).tint(Theme.Color.primary)

            HStack(spacing: 14) {
                Button { showDashboard = true } label: {
                    Label("Progress", systemImage: "chart.bar.fill")
                        .font(Theme.Font.label(18)).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.bordered).tint(Theme.Color.primary)

                if profile?.speedRoundUnlocked == true {
                    Button { speedRound = true; showSession = true } label: {
                        Label("Speed Round", systemImage: "timer")
                            .font(Theme.Font.label(18)).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered).tint(Theme.Color.accent)
                }
            }
        }
    }
}
