import SwiftUI
import SwiftData

/// The streak modal (from the map's flame chip): flame hero on top, then a
/// chunky kid-style month calendar — a gold tile with a flame on star-earned
/// days, a dot on practiced-without-star days.
struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var monthAnchor = Date.now

    private var profile: Profile? { activeProfiles.first }
    private let cal = Calendar.current
    private static let sheetBG = Color(red: 0.09, green: 0.10, blue: 0.14)

    /// Days (startOfDay) with a star-earning session / any practice at all.
    private var starDays: Set<Date> {
        Set((profile?.sessions ?? []).filter(\.starEarned).map { cal.startOfDay(for: $0.date) })
    }
    private var practiceDays: Set<Date> {
        Set((profile?.sessions ?? []).filter { $0.questionCount > 0 }
            .map { cal.startOfDay(for: $0.date) })
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26)).foregroundStyle(.white.opacity(0.7))
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
            }
            hero
            calendar
            Text("One rest day never breaks your streak.")
                .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
        }
        .padding(Theme.Metric.pad)
        .frame(minWidth: 840, minHeight: 900)
        .background(Self.sheetBG)
        .presentationBackground(Self.sheetBG)
    }

    private var hero: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 66))
                    .foregroundStyle(LinearGradient(colors: [Theme.Color.accent,
                                                             Color(red: 0.95, green: 0.35, blue: 0.1)],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.Color.accent.opacity(0.6), radius: 16)
                Text("\(profile?.streakDays ?? 0)")
                    .font(Theme.Font.display(66)).foregroundStyle(.white)
            }
            Text("DAY STREAK")
                .font(Theme.Font.label(24)).tracking(4)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var calendar: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canGoBack ? Theme.Color.accent : .white.opacity(0.15))
                }
                .disabled(!canGoBack)
                Spacer()
                Text(monthTitle)
                    .font(Theme.Font.display(22)).foregroundStyle(.white)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canGoForward ? Theme.Color.accent : .white.opacity(0.15))
                }
                .disabled(!canGoForward)
            }
            let symbols = cal.veryShortWeekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 7),
                      spacing: 9) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(i + cal.firstWeekday - 1) % 7])
                        .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.5))
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    dayTile(day)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
    }

    /// A chunky day tile: gold + flame on star days, dot on practiced days.
    @ViewBuilder
    private func dayTile(_ day: Date?) -> some View {
        if let day {
            let key = cal.startOfDay(for: day)
            let isToday = cal.isDateInToday(day)
            let future = key > cal.startOfDay(for: .now)
            let star = starDays.contains(key)
            let practiced = practiceDays.contains(key)
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(Theme.Font.number(17))
                    .foregroundStyle(star ? .white : .white.opacity(future ? 0.25 : 0.6))
                if star {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 27))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                } else if practiced {
                    Circle().fill(Theme.Color.accent).frame(width: 11, height: 11)
                        .padding(.vertical, 8)
                } else {
                    Color.clear.frame(height: 27)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(star
                          ? AnyShapeStyle(LinearGradient(
                                colors: [Theme.Color.accent,
                                         Color(red: 0.95, green: 0.55, blue: 0.1)],
                                startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(future ? 0.03 : 0.07))))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isToday ? Theme.Color.accent : .white.opacity(0.08),
                                  lineWidth: isToday ? 2.5 : 1)
            }
        } else {
            Color.clear.frame(height: 78)
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
