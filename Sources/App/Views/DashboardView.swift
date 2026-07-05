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
            card("Weekly overview") { weeklyOverview }
            card("Times-table proficiency") { tableProficiency }
            if !troubleSpots.isEmpty { card("Trouble spots") { trouble } }
            card("Mastery map") {
                ScrollView(.horizontal, showsIndicators: false) { MasteryGridView(facts: facts).padding(4) }
                legend
            }
            if sessions.count >= 2 { card("Progress over time") { trend } }
            if !unfulfilled.isEmpty { card("Earned rewards", badge: unfulfilled.count) { rewards } }
            card("Adventure map") {
                let cleared = profile?.clearedWorlds.count ?? 0
                Text("\(cleared) of \(WorldCatalog.count) worlds cleared")
                    .font(Theme.Font.number(22)).foregroundStyle(Theme.Color.primary)
                worldBars
            }
        }
        .frame(maxWidth: 720)
    }

    // MARK: Weekly overview (this week vs. last)

    private struct WeekStats {
        var days = 0, stars = 0, problems = 0, newFluent = 0
        var accuracy: Double?
    }

    private func stats(in interval: DateInterval?) -> WeekStats {
        guard let interval else { return WeekStats() }
        let cal = Calendar.current
        let recs = sessions.filter { interval.contains($0.date) }
        var s = WeekStats()
        s.days = Set(recs.map { cal.startOfDay(for: $0.date) }).count
        s.stars = recs.filter(\.starEarned).count
        s.problems = recs.reduce(0) { $0 + $1.questionCount }
        s.newFluent = recs.reduce(0) { $0 + $1.fluentGained }
        let q = recs.reduce(0) { $0 + $1.questionCount }
        let c = recs.reduce(0) { $0 + $1.correctCount }
        s.accuracy = q > 0 ? Double(c) / Double(q) : nil
        return s
    }

    private var weeklyOverview: some View {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: .now)
        let lastWeek = thisWeek.flatMap { i in
            cal.date(byAdding: .day, value: -7, to: i.start).flatMap {
                cal.dateInterval(of: .weekOfYear, for: $0)
            }
        }
        let now = stats(in: thisWeek)
        let prev = stats(in: lastWeek)
        let hasHistory = prev.problems > 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                statTile("calendar", "\(now.days)", "practice days",
                         hasHistory ? delta(now.days - prev.days) : nil, Theme.Color.primary)
                statTile("star.fill", "\(now.stars)", "stars earned",
                         hasHistory ? delta(now.stars - prev.stars) : nil, Theme.Color.accent)
                statTile("checkmark.circle.fill",
                         now.accuracy.map { "\(Int($0 * 100))%" } ?? "—", "accuracy",
                         hasHistory ? accuracyDelta(now.accuracy, prev.accuracy) : nil, Theme.Color.correct)
                statTile("number.square.fill", "\(now.problems)", "problems answered",
                         hasHistory ? delta(now.problems - prev.problems) : nil, Theme.Color.primary)
                statTile("bolt.fill", "\(now.newFluent)", "new fluent facts",
                         hasHistory ? delta(now.newFluent - prev.newFluent) : nil, Theme.Color.accent)
            }
            HStack(spacing: 14) {
                if let p = profile, p.streakDays > 0 {
                    Label("\(p.streakDays)-day streak", systemImage: "flame.fill")
                        .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.accent)
                }
                let pct = Int(Double(masteredCount) / Double(FactUniverse.count) * 100)
                Label("\(masteredCount)/\(FactUniverse.count) facts mastered (\(pct)%)",
                      systemImage: "medal.fill")
                    .font(Theme.Font.label(13)).foregroundStyle(Theme.Color.correct)
                if !hasHistory {
                    Text("First week — comparisons start next week!")
                        .font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
                }
            }
        }
    }

    private func delta(_ d: Int) -> (String, Color)? {
        if d > 0 { return ("▲ +\(d) vs last week", Theme.Color.correct) }
        if d < 0 { return ("▼ \(d) vs last week", Theme.Color.inkSoft) }
        return ("— same as last week", Theme.Color.inkSoft)
    }
    private func accuracyDelta(_ now: Double?, _ prev: Double?) -> (String, Color)? {
        guard let now, let prev else { return nil }
        let d = Int((now - prev) * 100)
        if d > 0 { return ("▲ +\(d) pts", Theme.Color.correct) }
        if d < 0 { return ("▼ \(d) pts", Theme.Color.inkSoft) }
        return ("— level", Theme.Color.inkSoft)
    }

    private func statTile(_ icon: String, _ value: String, _ label: String,
                          _ change: (String, Color)?, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(tint)
            Text(value).font(Theme.Font.number(26)).foregroundStyle(Theme.Color.ink)
            Text(label).font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
            if let (text, color) = change {
                Text(text).font(Theme.Font.label(10)).foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 4)
        .background(tint.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Times-table proficiency

    private enum TableStatus {
        case notStarted, working, needsAttention, mastered
        var label: String {
            switch self {
            case .notStarted: "Not started"; case .working: "Working on it"
            case .needsAttention: "Needs attention"; case .mastered: "Mastered"
            }
        }
        var color: Color {
            switch self {
            case .notStarted: Theme.Color.gentle
            case .working: Theme.Color.primary
            case .needsAttention: Theme.Color.accent
            case .mastered: Theme.Color.correct
            }
        }
    }

    private func tableStatus(_ tableFacts: [Fact]) -> TableStatus {
        guard tableFacts.contains(where: { $0.introduced }) else { return .notStarted }
        if tableFacts.allSatisfy({ $0.stage == .mastered }) { return .mastered }
        let struggling = tableFacts.contains {
            $0.introduced && (($0.totalAttempts >= 3 && $0.snapshot.accuracy < 0.7) || $0.lapseCount >= 2)
        }
        return struggling ? .needsAttention : .working
    }

    private var tableProficiency: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  alignment: .leading, spacing: 8) {
            ForEach(0...FactUniverse.maxFactor, id: \.self) { t in
                let tf = facts.filter { $0.a == t || $0.b == t }
                let status = tableStatus(tf)
                let fluent = tf.filter { $0.stage >= .fluency }.count
                HStack(spacing: 10) {
                    Text("×\(t)").font(Theme.Font.number(17)).foregroundStyle(Theme.Color.ink)
                        .frame(width: 42, alignment: .leading)
                    ProgressView(value: tf.isEmpty ? 0 : Double(fluent) / Double(tf.count))
                        .tint(status.color)
                    Text(status.label).font(Theme.Font.label(11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(status.color))
                        .frame(width: 118, alignment: .trailing)
                }
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

    /// Only facts with real evidence of struggle: missed repeatedly (under 75%
    /// over 3+ tries) or slipped after mastery twice. Being new or slow is
    /// normal learning, not trouble — with no threshold this card just listed
    /// his most recent facts and cried wolf.
    private var troubleSpots: [Fact] {
        facts.filter { f in
            guard f.introduced, f.stage != .mastered, min(f.a, f.b) > 1 else { return false }
            let struggling = f.totalAttempts >= 3 && f.snapshot.accuracy < 0.75
            return struggling || f.lapseCount >= 2
        }
        .sorted { troubleScore($0) > troubleScore($1) }.prefix(6).map { $0 }
    }
    private func troubleScore(_ f: Fact) -> Double {
        (1 - f.snapshot.accuracy) * 5 + Double(f.lapseCount) * 3 + max(0, f.averageTime - 2)
    }
    private var trouble: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(troubleSpots) { f in
                    Text("\(f.a)×\(f.b)").font(Theme.Font.number(18)).foregroundStyle(Theme.Color.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.Color.accent.opacity(0.15)).clipShape(Capsule())
                }
            }
            Text("Missed often or slipped after mastery — worth a minute together.")
                .font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
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
    private func card<Content: View>(_ title: String, badge: Int = 0,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(Theme.Font.label(13)).tracking(1.5)
                    .foregroundStyle(Theme.Color.inkSoft)
                if badge > 0 {
                    Text("\(badge)")
                        .font(Theme.Font.label(12)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.9, green: 0.2, blue: 0.18)))
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
    }
}
