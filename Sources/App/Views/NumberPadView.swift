import SwiftUI

/// Calculator-style number pad (7-8-9 top), large kid-friendly keys, positioned low
/// for two-handed iPad reach (§12).
struct NumberPadView: View {
    let enterEnabled: Bool
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onEnter: () -> Void

    private let rows = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) { ForEach(row, id: \.self) { digit(_: $0) } }
            }
            HStack(spacing: 12) {
                key(systemImage: "delete.left.fill", tint: Theme.Color.inkSoft, action: onDelete)
                    .accessibilityLabel("Delete")
                digit(0)
                key(systemImage: "checkmark", tint: Theme.Color.correct,
                    enabled: enterEnabled, action: onEnter)
                    .accessibilityLabel("Enter")
            }
        }
        .frame(maxWidth: 420)
    }

    private func digit(_ n: Int) -> some View {
        Button { onDigit(n) } label: {
            Text("\(n)").font(Theme.Font.number(34))
                .frame(maxWidth: .infinity, minHeight: 64)
                .foregroundStyle(Theme.Color.ink)
                .background(Theme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cornerSmall, style: .continuous))
        }
        .buttonStyle(PopButtonStyle(scale: 0.94))
    }

    private func key(systemImage: String, tint: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 26, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 64)
                .foregroundStyle(enabled ? tint : Theme.Color.inkSoft.opacity(0.4))
                .background(enabled ? tint.opacity(0.12) : Theme.Color.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cornerSmall, style: .continuous))
        }
        .buttonStyle(PopButtonStyle(scale: 0.94))
        .disabled(!enabled)
    }
}
