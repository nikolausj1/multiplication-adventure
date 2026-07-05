import SwiftUI
import SwiftData

/// The streak screen (from the map's flame chip): current streak hero + a month
/// calendar — flame on star-earned days, a dot on practiced-without-star days.
struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var monthAnchor = Date.now

    private var profile: Profile? { activeProfiles.first }
    private let cal = Calendar.current

    /// Days (startOfDay) with a star-earning session / any practice at all.
    private var starDays: Set<Date> {
        Set((profile?.sessions ?? []).filter(\.starEarned).map { cal.startOfDay(for: $0.date) })
    }
    private var practiceDays: Set<Date> {
        Set((profile?.sessions ?? []).filter { $0.questionCount > 0 }
            .map { cal.startOfDay(for: $0.date) })
    }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Theme.Metric.gap) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30)).foregroundStyle(.white)
                            .frame(width: 48, height: 48).contentShape(Rectangle())
                            .shadow(radius: 3)
                    }
                    .accessibilityLabel("Close")
                }
                HStack(alignment: .top, spacing: Theme.Metric.gap * 1.5) {
                    hero
                    calendarCard
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Metric.pad)
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            if Art.exists("map_bg") {
                Color.clear
                    .overlay(Image("map_bg").resizable().scaledToFill())
                    .clipped()
                    .opacity(0.35)
            }
            Color.black.opacity(0.4)
        }
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 84))
                .foregroundStyle(LinearGradient(colors: [Theme.Color.accent,
                                                         Color(red: 0.95, green: 0.35, blue: 0.1)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.Color.accent.opacity(0.6), radius: 18)
            Text("\(profile?.streakDays ?? 0)")
                .font(Theme.Font.display(64)).foregroundStyle(.white)
            Text("DAY STREAK")
                .font(Theme.Font.label(16)).tracking(3)
                .foregroundStyle(.white.opacity(0.7))
            Text("One rest day never breaks your streak.")
                .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 300)
        .darkPlate()
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(canGoBack ? .white : .white.opacity(0.25))
                        .frame(width: 40, height: 40)
                }
                .disabled(!canGoBack)
                Spacer()
                Text(monthTitle)
                    .font(Theme.Font.display(20)).foregroundStyle(.white)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(canGoForward ? .white : .white.opacity(0.25))
                        .frame(width: 40, height: 40)
                }
                .disabled(!canGoForward)
            }
            let symbols = cal.veryShortWeekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(i + cal.firstWeekday - 1) % 7])
                        .font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.5))
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: .infinity)
        .darkPlate()
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let key = cal.startOfDay(for: day)
            let isToday = cal.isDateInToday(day)
            let future = key > cal.startOfDay(for: .now)
            VStack(spacing: 2) {
                if starDays.contains(key) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Color.accent)
                } else if practiceDays.contains(key) {
                    Circle().fill(.white.opacity(0.8)).frame(width: 7, height: 7)
                        .padding(.vertical, 5.5)
                } else {
                    Text("\(cal.component(.day, from: day))")
                        .font(Theme.Font.label(13))
                        .foregroundStyle(.white.opacity(future ? 0.2 : 0.45))
                        .padding(.vertical, 1)
                }
            }
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Theme.Color.accent.opacity(0.8), lineWidth: 2)
                }
            }
        } else {
            Color.clear.frame(height: 34)
        }
    }

    // MARK: Month math

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor
    }
    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }
    private var monthCells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            cells.append(cal.date(byAdding: .day, value: d - 1, to: monthStart))
        }
        return cells
    }
    private var earliestMonth: Date {
        let created = profile?.createdAt ?? .now
        return cal.date(from: cal.dateComponents([.year, .month], from: created)) ?? created
    }
    private var canGoBack: Bool { monthStart > earliestMonth }
    private var canGoForward: Bool {
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return monthStart < thisMonth
    }
    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }
}
