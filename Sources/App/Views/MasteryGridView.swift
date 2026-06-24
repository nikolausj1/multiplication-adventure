import SwiftUI

/// The mastery map (§8): the times-table grid, each fact colour-coded by state with
/// an always-on stage badge (1–3) and a star when mastered. Colour + shape/badge so
/// state never relies on colour alone.
struct MasteryGridView: View {
    let facts: [Fact]

    private let range = FactUniverse.minFactor...FactUniverse.maxFactor
    private var lookup: [FactID: Fact] {
        Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
    }

    var body: some View {
        let map = lookup
        VStack(spacing: 3) {
            // Header row of factors.
            HStack(spacing: 3) {
                corner
                ForEach(range, id: \.self) { axisLabel($0) }
            }
            ForEach(range, id: \.self) { row in
                HStack(spacing: 3) {
                    axisLabel(row)
                    ForEach(range, id: \.self) { col in
                        cell(map[FactID(row, col)])
                    }
                }
            }
        }
    }

    private var corner: some View {
        Image(systemName: "multiply").font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.Color.inkSoft).frame(width: 24, height: 24)
    }

    private func axisLabel(_ n: Int) -> some View {
        Text("\(n)").font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.Color.inkSoft).frame(width: 24, height: 24)
    }

    @ViewBuilder
    private func cell(_ fact: Fact?) -> some View {
        let state = fact?.snapshot.displayState ?? .notStarted
        let stage = fact?.stage ?? .recognition
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.Color.state(state))
            if state == .mastered {
                Image(systemName: "star.fill").font(.system(size: 9))
                    .foregroundStyle(.white)
            } else if state != .notStarted, let badge = stage.badge {
                Text("\(badge)").font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
    }
}
