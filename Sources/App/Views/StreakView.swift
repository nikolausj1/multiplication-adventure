import SwiftUI
import SwiftData

/// The streak modal (from the map's flame chip): flame hero on top, then a
/// chunky kid-style month calendar — a gold tile with a flame on star-earned
/// days, a dot on practiced-without-star days.
struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var monthAnchor = Date.now

    private var compact: Bool { vSize == .compact }
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
        ZStack {
            // Dimmed map behind the card; tap outside to dismiss.
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            card
                .frame(maxWidth: 880)
                .padding(.vertical, 26)
        }
        .presentationBackground(.clear)
    }

    private var card: some View {
        Group {
            // On iPhone landscape, a ScrollView is a safety net so the card
            // never hard-clips; iPad keeps the existing non-scrolling layout.
            if compact { ScrollView { cardStack } } else { cardStack }
        }
        .padding(Theme.Metric.pad)
        .overlay(alignment: .topLeading) { ModalCloseButton { dismiss() }.padding(14) }
        .background(Self.sheetBG, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }

    private var cardStack: some View {
        VStack(spacing: compact ? 10 : 16) {
            hero
            calendar
                .frame(maxHeight: compact ? 240 : .infinity)
            Text("One rest day never breaks your streak.")
                .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.55))
        }
    }

    private var hero: some View {
        VStack(spacing: compact ? 4 : 8) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: compact ? 44 : 66))
                    .foregroundStyle(LinearGradient(colors: [Theme.Color.accent,
                                                             Color(red: 0.95, green: 0.35, blue: 0.1)],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.Color.accent.opacity(0.6), radius: 16)
                Text("\(profile?.streakDays ?? 0)")
                    .font(Theme.Font.display(compact ? 40 : 66)).foregroundStyle(.white)
            }
            Text("DAY STREAK")
                .font(Theme.Font.label(compact ? 18 : 24)).tracking(4)
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
            HStack(spacing: 9) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(i + cal.firstWeekday - 1) % 7])
                        .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            // The grid stretches to fill whatever height the card gives it.
            GeometryReader { geo in
                let cells = monthCells
                let rows = max(1, Int(ceil(Double(cells.count) / 7)))
                let tileH = max(compact ? 32 : 56, (geo.size.height - CGFloat(rows - 1) * 9) / CGFloat(rows))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 7),
                          spacing: 9) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        dayTile(day, height: tileH)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
    }

    /// A chunky day tile: gold + flame on star days, dot on practiced days.
    @ViewBuilder
    private func dayTile(_ day: Date?, height: CGFloat = 78) -> some View {
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
            .frame(height: height)
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
            Color.clear.frame(height: height)
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
