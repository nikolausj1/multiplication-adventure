import SwiftUI

/// The times-table reference (from the map's table chip): pick a table on the
/// left rail (×0…×11, or ALL for the full product grid) and read the answers.
/// A plain answer chart — no mastery coloring — and deliberately map-only:
/// a lookup between quests, never available mid-session.
struct TimesTableView: View {
    @Environment(\.dismiss) private var dismiss

    /// nil = the ALL product grid.
    @State private var selectedTable: Int? = 1

    private static let sheetBG = Color(red: 0.09, green: 0.10, blue: 0.14)
    private let maxFactor = FactUniverse.maxFactor

    var body: some View {
        ZStack {
            // Dimmed map behind the card; tap outside to dismiss.
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            card
                .frame(maxWidth: 1080)
                .padding(.vertical, 26)
        }
        .presentationBackground(.clear)
        .onAppear {
            // Screenshot hook (simulator verification only).
            if ProcessInfo.processInfo.arguments.contains("-timesTableAll") { selectedTable = nil }
        }
    }

    private var card: some View {
        VStack(spacing: 12) {
            Text("TIMES TABLES")
                .font(Theme.Font.label(20)).tracking(5)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 10)
            HStack(alignment: .top, spacing: 16) {
                rail
                Group {
                    if let t = selectedTable {
                        tableList(t)
                    } else {
                        allGrid
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
            }
            .frame(maxHeight: .infinity)
        }
        .padding(Theme.Metric.pad)
        .overlay(alignment: .topLeading) { ModalCloseButton { dismiss() }.padding(14) }
        .background(Self.sheetBG, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }

    // MARK: Left rail — one button per table + ALL

    private var rail: some View {
        VStack(spacing: 7) {
            ForEach(0...maxFactor, id: \.self) { t in
                railButton(label: "×\(t)", isSelected: selectedTable == t) {
                    selectedTable = t
                }
            }
            railButton(label: "ALL", isSelected: selectedTable == nil) {
                selectedTable = nil
            }
        }
        .frame(width: 86)
        .padding(.top, 26)   // clear the close key above
    }

    private func railButton(label: String, isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button {
            Feedback.fire(.keyTap)
            action()
        } label: {
            Text(label)
                .font(Theme.Font.number(19))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AnyShapeStyle(Theme.Color.accent)
                                         : AnyShapeStyle(Color.white.opacity(0.08))))
        }
        .buttonStyle(PopButtonStyle())
        .accessibilityLabel(label == "ALL" ? "All tables" : "\(label) table")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: One table — 12 big equations in two columns

    private func tableList(_ t: Int) -> some View {
        let half = (maxFactor + 2) / 2   // 0…11 → 6 rows per column
        return VStack(spacing: 0) {
            ForEach(0..<half, id: \.self) { row in
                HStack(spacing: 12) {
                    equation(t, row)
                    equation(t, row + half)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 12)
    }

    private func equation(_ t: Int, _ n: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(t) × \(n)")
                .font(Theme.Font.number(30))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 128, alignment: .trailing)
            Text("=")
                .font(Theme.Font.number(26))
                .foregroundStyle(.white.opacity(0.45))
            Text("\(t * n)")
                .font(Theme.Font.number(34))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 84, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(t) times \(n) equals \(t * n)")
    }

    // MARK: ALL — the classic product grid with row/column headers

    private var allGrid: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                gridCell("×", header: true)
                ForEach(0...maxFactor, id: \.self) { c in
                    gridCell("\(c)", header: true)
                }
            }
            ForEach(0...maxFactor, id: \.self) { r in
                GridRow {
                    gridCell("\(r)", header: true)
                    ForEach(0...maxFactor, id: \.self) { c in
                        gridCell("\(r * c)")
                    }
                }
            }
        }
        .padding(14)
    }

    private func gridCell(_ text: String, header: Bool = false) -> some View {
        Text(text)
            .font(Theme.Font.number(header ? 19 : 18))
            .foregroundStyle(header ? Theme.Color.accent : .white.opacity(0.9))
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(header ? 0.11 : 0.04)))
    }
}
