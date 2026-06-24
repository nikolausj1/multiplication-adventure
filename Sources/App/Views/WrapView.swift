import SwiftUI
import SwiftData

/// Session wrap (§6, movement 4): a clear, encouraging summary. He always leaves
/// knowing he made progress — a short day still counts.
struct WrapView: View {
    let vm: SessionViewModel
    let onDone: () -> Void

    @Query private var facts: [Fact]
    private var masteredCount: Int { facts.filter { $0.stage == .mastered }.count }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80)).foregroundStyle(Theme.Color.correct)
                .symbolRenderingMode(.hierarchical)
            Text("Great work!").font(Theme.Font.display(36)).foregroundStyle(Theme.Color.ink)

            HStack(spacing: 28) {
                stat("\(vm.totalAnswered)", "questions")
                stat("\(Int(vm.accuracy * 100))%", "accuracy")
                stat("+\(vm.xpEarned)", "XP", tint: Theme.Color.accent)
            }
            .padding(.vertical, 20).padding(.horizontal, 28).cardSurface()

            if let next = RankLadder.next(afterMasteredCount: masteredCount) {
                Text("\(next.remaining) more facts to \(next.rank.name)")
                    .font(Theme.Font.body()).foregroundStyle(Theme.Color.inkSoft)
            }
            if let c = vm.endCelebration, c.tier >= .t1 {
                Label(c.headline, systemImage: "flame.fill")
                    .font(Theme.Font.label(17)).foregroundStyle(Theme.Color.accent)
            }
            Text(encouragement).font(Theme.Font.body()).foregroundStyle(Theme.Color.ink)
                .multilineTextAlignment(.center).padding(.horizontal, 40)

            Spacer()
            Button(action: onDone) {
                Text("Done").font(Theme.Font.display(22))
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent).tint(Theme.Color.primary)
            .frame(maxWidth: 420)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 560)
    }

    private func stat(_ value: String, _ label: String, tint: Color = Theme.Color.ink) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.Font.number(30)).foregroundStyle(tint)
            Text(label).font(Theme.Font.label(13)).foregroundStyle(Theme.Color.inkSoft)
        }
    }

    private var encouragement: String {
        if vm.accuracy >= 0.9 { return "You're getting faster every day. 🚀" }
        if vm.totalAnswered >= 15 { return "Showing up is what makes it stick. See you tomorrow!" }
        return "Every bit of practice counts. Nice job today!"
    }
}
