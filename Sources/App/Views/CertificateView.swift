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
    /// Golden Guardians phase 4, beat 2: true once every world is gilded.
    /// Renders a gold seal on the card — the certificate he already owns
    /// gaining a mark of the deeper accomplishment, not a second certificate.
    /// Callers derive this from the profile (`gildedWorlds.count == WorldCatalog.count`).
    var goldSeal: Bool = false

    @State private var rendered: Image?

    private var compact: Bool { vSize == .compact }
    private var profile: Profile? { activeProfiles.first }
    private static let gold = Color(hex: "#C9A24B")
    private static let goldDeep = Color(hex: "#A87F2E")
    /// Warm parchment inks. Theme.Color.ink/inkSoft are cool blue-greys tuned
    /// for the app's light UI; on aged paper they read as the wrong document.
    private static let paperInk = Color(hex: "#2E1F0C")
    private static let paperInkSoft = Color(hex: "#7A6240")

    var body: some View {
        ZStack {
            // The gilded art IS the moment, so everything around it gets out of
            // the way. A white sheet card used to frame it and kill the impact.
            LinearGradient(colors: [Color(hex: "#241A0E"), Color(hex: "#0C0805")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // One scaling path for both devices: lay the card out at its design
            // size and scale the whole thing (art AND type together) to fill the
            // space available. iPad gets to grow into the room it has instead of
            // sitting at a fixed 680pt in the middle of a 1180pt screen.
            GeometryReader { geo in
                let btnH: CGFloat = compact ? 42 : 54
                let gap: CGFloat = compact ? 14 : 26
                let availW = geo.size.width - (compact ? 30 : 90)
                let availH = geo.size.height - btnH - gap - (compact ? 26 : 70)
                let s = min(availW / 680, availH / 470, compact ? 1.0 : 1.5)
                VStack(spacing: gap) {
                    certificate
                        .frame(width: 680, height: 470)
                        .scaleEffect(s, anchor: .center)
                        .frame(width: 680 * s, height: 470 * s)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.65), radius: 30, y: 16)
                    buttonRow(height: btnH)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear(perform: render)
    }

    /// Matched pair: identical height, identical shape, identical type. Only the
    /// fill separates primary from secondary — the old pair mixed a prominent
    /// blue capsule with a bordered text button at a different height.
    private func buttonRow(height: CGFloat) -> some View {
        let font = Theme.Font.label(compact ? 15 : 18)
        return HStack(spacing: 14) {
            if let rendered {
                ShareLink(item: rendered,
                          preview: SharePreview("Certificate of Mastery", image: rendered)) {
                    Label("Share / Print", systemImage: "square.and.arrow.up")
                        .font(font)
                        .foregroundStyle(Color(hex: "#3A2708"))
                        .frame(width: compact ? 186 : 234, height: height)
                        .background(Capsule().fill(LinearGradient(
                            colors: [Color(hex: "#E8C46A"), Self.goldDeep],
                            startPoint: .top, endPoint: .bottom)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.38), lineWidth: 1))
                }
            }
            Button { dismiss() } label: {
                Text("Done")
                    .font(font)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: compact ? 116 : 146, height: height)
                    .background(Capsule().fill(.white.opacity(0.13)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
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
                    .foregroundStyle(Self.paperInk)
                Text("This certifies that")
                    .font(Theme.Font.body(15)).foregroundStyle(Self.paperInkSoft)

                // Gilded, engraved-into-the-parchment — NOT Theme.Color.primary.
                // The app's friendly blue is the one colour on this page that
                // belongs to a UI kit rather than to a certificate, and it made
                // the name read as if it came from a different product.
                Text(name)
                    .font(Theme.Font.display(46))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#7A4E15"), Color(hex: "#472A09")],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: Self.gold.opacity(0.5), radius: 6, y: 2)
                    .lineLimit(1).minimumScaleFactor(0.6)

                Text("has mastered all \(FactUniverse.count) multiplication facts —\nthe times tables from 0 to \(FactUniverse.maxFactor) — and conquered the Seven Worlds.")
                    .multilineTextAlignment(.center)
                    .font(Theme.Font.body(16))
                    .foregroundStyle(Self.paperInk)

                // Earned stats + date.
                HStack(spacing: 20) {
                    statBadge("star.fill", "\(profile?.questStars ?? 0) stars")
                    statBadge("bolt.fill", "best streak \(profile?.bestStreak ?? 0)")
                    statBadge("calendar", Date().formatted(date: .abbreviated, time: .omitted))
                }
                .padding(.top, 8)
            }
            // `certificate_bg` has a trophy painted into the top of the card, so
            // the text block starts below it instead of on top of it. The drawn
            // parchment fallback renders its own trophy inline and needs no gap.
            .padding(.horizontal, 90)
            .padding(.top, Art.exists("certificate_bg") ? 132 : 40)
            .padding(.bottom, 30)

            // Golden Guardians phase 4, beat 2: the gold seal. Lower corner,
            // mirroring where `certificate_bg`'s own baked-in wax seal sits
            // in the OPPOSITE (bottom-right) corner — that placement is
            // already proven clear of the centered text column above, so its
            // mirror image on the left is too. Lives inside this `certificate`
            // view (not layered on top by a caller) so the ImageRenderer
            // share path picks it up automatically.
            if goldSeal {
                goldSealBadge
                    .position(x: 116, y: 404)
            }
        }
    }

    /// Layered gold circles + star + a tiny ribbon caption — the whole
    /// element is drawn (no new art), matching the certificate's engraved-
    /// gold language rather than pasting on a generic badge.
    private var goldSealBadge: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#F7E3A6"), Self.gold, Self.goldDeep],
                                     center: .center, startRadius: 2, endRadius: 48))
            Circle().strokeBorder(Color(hex: "#FFF6DC"), lineWidth: 2).padding(3)
            Circle().strokeBorder(Self.goldDeep.opacity(0.65), lineWidth: 1).padding(8)
            VStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                Text("SEVEN WORLDS")
                    .font(Theme.Font.label(7)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.95))
                Text("GOLDEN GUARDIAN")
                    .font(Theme.Font.label(6)).tracking(0.4)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: 92, height: 92)
        .rotationEffect(.degrees(-9))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .overlay(
            // Two small ribbon tails beneath the medallion, echoing the art's
            // own wax-seal-and-ribbon motif on the opposite corner.
            HStack(spacing: 26) {
                RoundedRectangle(cornerRadius: 2).fill(Self.goldDeep)
                    .frame(width: 11, height: 24)
                    .rotationEffect(.degrees(14))
                RoundedRectangle(cornerRadius: 2).fill(Self.goldDeep)
                    .frame(width: 11, height: 24)
                    .rotationEffect(.degrees(-14))
            }
            .offset(y: 42),
            alignment: .center
        )
    }

    private func statBadge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.goldDeep)
            Text(text).font(Theme.Font.label(14)).foregroundStyle(Self.paperInkSoft)
        }
    }
}
