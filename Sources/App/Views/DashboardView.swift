import SwiftUI
import SwiftData
import Charts

/// The parent dashboard (§8): plain language, readable in under 30 seconds,
/// transparent/shared. Scoped to the active profile. Embeddable in the parent area.
struct DashboardView: View {
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    private var profile: Profile? { activeProfiles.first }
    private var facts: [Fact] { profile?.facts ?? [] }
    private var sessions: [SessionRecord] { (profile?.sessions ?? []).sorted { $0.date < $1.date } }
    private var milestones: [MilestoneRecord] { (profile?.milestones ?? []).sorted { $0.earnedDate > $1.earnedDate } }
    private var masteredCount: Int { facts.filter { $0.stage == .mastered }.count }

    var body: some View {
        VStack(spacing: Theme.Metric.gap) {
            cadenceAndMastery
            card("Adventure map") {
                let cleared = profile?.clearedWorlds.count ?? 0
                Text("\(cleared) of \(WorldCatalog.count) worlds cleared")
                    .font(Theme.Font.number(22)).foregroundStyle(Theme.Color.primary)
                worldBars
            }
            card("Mastery map") {
                ScrollView(.horizontal, showsIndicators: false) { MasteryGridView(facts: facts).padding(4) }
                legend
            }
            if sessions.count >= 2 { card("Progress over time") { trend } }
            if !troubleSpots.isEmpty { card("Trouble spots") { trouble } }
            if !unfulfilled.isEmpty { card("Earned rewards") { rewards } }
        }
        .frame(maxWidth: 720)
    }

    private var cadenceAndMastery: some View {
        HStack(spacing: Theme.Metric.gap) {
            card("This week") {
                Text("\(daysPracticedThisWeek)/7").font(Theme.Font.number(34)).foregroundStyle(Theme.Color.primary)
                Text("days practiced").font(Theme.Font.label(13)).foregroundStyle(Theme.Color.inkSoft)
                if let p = profile, p.streakDays > 0 {
                    Label("\(p.streakDays)-day streak", systemImage: "flame.fill")
                        .font(Theme.Font.label()).foregroundStyle(Theme.Color.accent)
                }
            }
            card("Mastered") {
                let pct = Int(Double(masteredCount) / Double(FactUniverse.count) * 100)
                Text("\(pct)%").font(Theme.Font.number(34)).foregroundStyle(Theme.Color.correct)
                ProgressView(value: Double(masteredCount), total: Double(FactUniverse.count)).tint(Theme.Color.correct)
                Text("\(masteredCount) of \(FactUniverse.count) facts")
                    .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.inkSoft)
            }
        }
    }

    private var worldBars: some View {
        let stats = WorldProgress.stats(snapshots: facts.map(\.snapshot))
        return VStack(spacing: 6) {
            ForEach(WorldCatalog.worlds, id: \.index) { w in
                let s = stats[w.index]
                HStack(spacing: 8) {
                    Text(w.name).font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
                        .frame(width: 110, alignment: .leading)
                    ProgressView(value: s.fluentFraction).tint(Color(hex: w.palette.primary))
                    if profile?.clearedWorlds.contains(w.index) == true {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Color.correct).font(.system(size: 13))
                    } else if s.cleared {
                        // All facts fluent, boss not yet beaten.
                        Image(systemName: "flag.checkered").foregroundStyle(Theme.Color.accent).font(.system(size: 13))
                    }
                }
            }
        }
    }

    private var trend: some View {
        Chart(sessions) { s in
            LineMark(x: .value("Date", s.date), y: .value("Accuracy", s.accuracy * 100))
                .foregroundStyle(Theme.Color.correct).interpolationMethod(.catmullRom)
            LineMark(x: .value("Date", s.date), y: .value("Speed", min(s.medianResponseTime, 6)))
                .foregroundStyle(Theme.Color.primary).interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale(["Accuracy %": Theme.Color.correct, "Median seconds": Theme.Color.primary])
        .frame(height: 180)
    }

    private var troubleSpots: [Fact] {
        facts.filter { $0.introduced && $0.stage != .mastered && $0.totalAttempts >= 2 }
            .sorted { troubleScore($0) > troubleScore($1) }.prefix(6).map { $0 }
    }
    private func troubleScore(_ f: Fact) -> Double {
        (1 - f.snapshot.accuracy) * 5 + Double(f.lapseCount) * 3 + max(0, f.averageTime - 2)
    }
    private var trouble: some View {
        HStack(spacing: 8) {
            ForEach(troubleSpots) { f in
                Text("\(f.a)×\(f.b)").font(Theme.Font.number(18)).foregroundStyle(Theme.Color.ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.Color.accent.opacity(0.15)).clipShape(Capsule())
            }
        }
    }

    private var unfulfilled: [MilestoneRecord] { milestones.filter { !$0.fulfilled } }
    private var rewards: some View {
        VStack(spacing: 10) {
            ForEach(unfulfilled) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.kindLabel).font(Theme.Font.label(16)).foregroundStyle(Theme.Color.ink)
                        Text(m.detail).font(Theme.Font.label(13)).foregroundStyle(Theme.Color.inkSoft)
                    }
                    Spacer()
                    Button("Given") { m.fulfilled = true }
                        .font(Theme.Font.label(14)).buttonStyle(.bordered).tint(Theme.Color.correct)
                }
            }
        }
    }

    private var daysPracticedThisWeek: Int {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return Set(sessions.filter { $0.date >= weekStart }.map { cal.startOfDay(for: $0.date) }).count
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([(FactDisplayState.notStarted, "New"), (.learning, "Learning"),
                     (.fluent, "Fluent"), (.mastered, "Mastered")], id: \.1) { state, label in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.Color.state(state)).frame(width: 14, height: 14)
                    Text(label).font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
                }
            }
        }.padding(.top, 8)
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.Font.label(15)).foregroundStyle(Theme.Color.inkSoft)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
    }
}
