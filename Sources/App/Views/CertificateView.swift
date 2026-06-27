import SwiftUI

/// The completion certificate (§10): shown when all 91 facts are mastered. Renders to
/// an image that can be shared or printed via the system share sheet.
struct CertificateView: View {
    @Environment(\.dismiss) private var dismiss
    let name: String

    @State private var rendered: Image?

    var body: some View {
        VStack(spacing: 20) {
            certificate
                .frame(width: 640, height: 440)
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
        let r = ImageRenderer(content: certificate.frame(width: 1280, height: 880))
        r.scale = 2
        #if canImport(UIKit)
        if let ui = r.uiImage { rendered = Image(uiImage: ui) }
        #endif
    }

    /// The renderable certificate artwork.
    private var certificate: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFF7E6"), Color(hex: "#FDE9C8")],
                           startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#C9A24B"), lineWidth: 8).padding(16)
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#C9A24B").opacity(0.5), lineWidth: 2).padding(26)

            VStack(spacing: 14) {
                Image(systemName: "trophy.fill").font(.system(size: 64))
                    .foregroundStyle(Color(hex: "#E0A82E"))
                Text("Certificate of Mastery")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Color.ink)
                Text("This certifies that").font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Theme.Color.inkSoft)
                Text(name).font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.primary)
                Text("has completed Multiplication Adventure and knows the\nmultiplication tables from 0 to 12.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Color.ink)
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(Theme.Color.inkSoft)
                    .padding(.top, 6)
            }
            .padding(40)
        }
    }
}
