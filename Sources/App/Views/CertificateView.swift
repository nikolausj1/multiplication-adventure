import SwiftUI
import SwiftData

/// The completion certificate (§10): shown when every fact is mastered. Renders to
/// an image that can be shared or printed via the system share sheet. Personalized
/// with the child's avatar, real stats, and the seven conquered worlds.
struct CertificateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]
    let name: String

    @State private var rendered: Image?

    private var compact: Bool { vSize == .compact }
    private var profile: Profile? { activeProfiles.first }
    private static let gold = Color(hex: "#C9A24B")
    private static let goldDeep = Color(hex: "#A87F2E")

    var body: some View {
        VStack(spacing: compact ? 12 : 20) {
            // iPad keeps the exact fixed frame; iPhone landscape aspect-fits the
            // preview into the short screen. (The exported ImageRenderer size in
            // render() is unchanged.)
            Group {
                if compact {
                    certificate
                        .aspectRatio(680.0 / 470.0, contentMode: .fit)
                        .frame(maxWidth: 680, maxHeight: .infinity)
                } else {
                    certificate
                        .frame(width: 680, height: 470)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)

            HStack(spacing: 14) {
                if let rendered {
                    ShareLink(item: rendered,
                              preview: SharePreview("Certificate of Mastery", image: rendered)) {
                        Label("Share / Print", systemImage: "square.and.arrow.up")
                            .font(Theme.Font.display(compact ? 15 : 18))
                            .padding(.horizontal, compact ? 14 : 20).padding(.vertical, compact ? 9 : 14)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.Color.primary)
                }
                Button("Done") { dismiss() }
                    .font(Theme.Font.display(compact ? 15 : 18))
                    .padding(.horizontal, compact ? 14 : 20).padding(.vertical, compact ? 9 : 14)
                    .buttonStyle(.bordered)
            }
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.bg)
        .onAppear(perform: render)
    }

    private func render() {
        let r = ImageRenderer(content: certificate.frame(width: 1360, height: 940))
        r.scale = 2
        #if canImport(UIKit)
        if let ui = r.uiImage { rendered = Image(uiImage: ui) }
        #endif
    }

    /// The renderable certificate artwork. When the generated `certificate_bg`
    /// asset exists (ornate frame + trophy baked into the art, empty center
    /// band for text), it becomes the whole page and we only overlay the text;
    /// until then a drawn parchment stands in.
    private var certificate: some View {
        ZStack {
            if Art.exists("certificate_bg") {
                Color.clear
                    .overlay(Image("certificate_bg").resizable().scaledToFill())
                    .clipped()
            } else {
                LinearGradient(colors: [Color(hex: "#FFF9EC"), Color(hex: "#FBE7C2")],
                               startPoint: .top, endPoint: .bottom)
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    LinearGradient(colors: [Self.gold, Self.goldDeep, Self.gold],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 8).padding(14)
                RoundedRectangle(cornerRadius: 8).strokeBorder(Self.gold.opacity(0.45), lineWidth: 2)
                    .padding(24)
            }

            VStack(spacing: 10) {
                // Trophy: baked into certificate_bg art when present; drawn gold
                // SF trophy on the interim parchment.
                if !Art.exists("certificate_bg") {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 1, green: 0.85, blue: 0.35),
                                     Color(red: 0.95, green: 0.63, blue: 0.1)],
                            startPoint: .top, endPoint: .bottom))
                        .shadow(color: Self.gold.opacity(0.5), radius: 8, y: 3)
                        .padding(.bottom, 2)
                }
                Text("CERTIFICATE OF MASTERY")
                    .font(Theme.Font.label(22)).tracking(5)
                    .foregroundStyle(Theme.Color.ink)
                Text("This certifies that")
                    .font(Theme.Font.body(15)).foregroundStyle(Theme.Color.inkSoft)

                Text(name)
                    .font(Theme.Font.display(44))
                    .foregroundStyle(Theme.Color.primary)
                    .lineLimit(1).minimumScaleFactor(0.6)

                Text("has mastered all \(FactUniverse.count) multiplication facts —\nthe times tables from 0 to \(FactUniverse.maxFactor) — and conquered the Seven Worlds.")
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.body(16))
                    .foregroundStyle(Theme.Color.ink)

                // Earned stats + date.
                HStack(spacing: 20) {
                    statBadge("star.fill", "\(profile?.questStars ?? 0) stars")
                    statBadge("bolt.fill", "best streak \(profile?.bestStreak ?? 0)")
                    statBadge("calendar", Date().formatted(date: .abbreviated, time: .omitted))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 90).padding(.vertical, 40)
        }
    }

    private func statBadge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.goldDeep)
            Text(text).font(Theme.Font.label(14)).foregroundStyle(Theme.Color.inkSoft)
        }
    }
}
