import SwiftUI
import SwiftData

/// The completion certificate (§10): shown when every fact is mastered. Renders to
/// an image that can be shared or printed via the system share sheet. Personalized
/// with the child's avatar, real stats, and the seven conquered worlds.
struct CertificateView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]
    let name: String

    @State private var rendered: Image?

    private var profile: Profile? { activeProfiles.first }
    private static let gold = Color(hex: "#C9A24B")
    private static let goldDeep = Color(hex: "#A87F2E")

    var body: some View {
        VStack(spacing: 20) {
            certificate
                .frame(width: 680, height: 470)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)

            HStack(spacing: 14) {
                if let rendered {
                    ShareLink(item: rendered,
                              preview: SharePreview("Certificate of Mastery", image: rendered)) {
                        Label("Share / Print", systemImage: "square.and.arrow.up")
                            .font(Theme.Font.display(18)).padding(.horizontal, 20).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.Color.primary)
                }
                Button("Done") { dismiss() }
                    .font(Theme.Font.display(18)).padding(.horizontal, 20).padding(.vertical, 14)
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

    /// The renderable certificate artwork.
    private var certificate: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFF9EC"), Color(hex: "#FBE7C2")],
                           startPoint: .top, endPoint: .bottom)
            // Faint giant star watermark behind everything.
            Image(systemName: "star.fill")
                .font(.system(size: 330))
                .foregroundStyle(Self.gold.opacity(0.07))
            RoundedRectangle(cornerRadius: 12).strokeBorder(
                LinearGradient(colors: [Self.gold, Self.goldDeep, Self.gold],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 8).padding(14)
            RoundedRectangle(cornerRadius: 8).strokeBorder(Self.gold.opacity(0.45), lineWidth: 2)
                .padding(24)

            VStack(spacing: 9) {
                // The game's own logo art crowns the page.
                if Art.exists("map_header") {
                    Image("map_header").resizable().scaledToFit()
                        .frame(height: 88)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                } else {
                    Text("Multiplication Adventure")
                        .font(Theme.Font.display(26)).foregroundStyle(Self.goldDeep)
                }
                Text("CERTIFICATE OF MASTERY")
                    .font(Theme.Font.label(21)).tracking(5)
                    .foregroundStyle(Theme.Color.ink)
                Text("This certifies that")
                    .font(Theme.Font.body(14)).foregroundStyle(Theme.Color.inkSoft)

                HStack(spacing: 14) {
                    AvatarBadge(key: profile?.avatarSymbol ?? "avatar1", size: 54)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    Text(name)
                        .font(Theme.Font.display(40))
                        .foregroundStyle(Theme.Color.primary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }

                Text("has mastered all \(FactUniverse.count) multiplication facts —\nthe times tables from 0 to \(FactUniverse.maxFactor) — and conquered the Seven Worlds.")
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.body(15))
                    .foregroundStyle(Theme.Color.ink)

                // The seven worlds, as their map badges.
                HStack(spacing: 13) {
                    ForEach(WorldCatalog.worlds, id: \.index) { w in
                        let theme = WorldTheme.forWorld(w.index)
                        if Art.exists(theme.nodeImage) {
                            Image(theme.nodeImage).resizable().scaledToFit()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Self.gold, lineWidth: 1.6))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        } else {
                            Circle().fill(theme.primary).frame(width: 44, height: 44)
                                .overlay(Circle().strokeBorder(Self.gold, lineWidth: 1.6))
                        }
                    }
                }
                .padding(.top, 3)

                // Earned stats + date.
                HStack(spacing: 18) {
                    statBadge("star.fill", "\(profile?.questStars ?? 0) stars")
                    statBadge("bolt.fill", "best streak \(profile?.bestStreak ?? 0)")
                    statBadge("calendar", Date().formatted(date: .abbreviated, time: .omitted))
                }
                .padding(.top, 5)
            }
            .padding(.horizontal, 48).padding(.vertical, 34)

            // Gold seal, bottom-right.
            VStack(spacing: 1) {
                StarGlyph(filled: true, size: 42)
                Text("MASTER")
                    .font(Theme.Font.label(9)).tracking(2)
                    .foregroundStyle(Self.goldDeep)
            }
            .padding(10)
            .background(Circle().fill(Self.gold.opacity(0.14)))
            .overlay(Circle().strokeBorder(Self.gold.opacity(0.6), lineWidth: 1.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(34)
        }
    }

    private func statBadge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Self.goldDeep)
            Text(text).font(Theme.Font.label(13)).foregroundStyle(Theme.Color.inkSoft)
        }
    }
}
