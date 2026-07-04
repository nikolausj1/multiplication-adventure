import SwiftUI

/// The app root — the adventure map is the home/hub (§3/§6: the child never picks
/// what to study; one tap on the current world starts a session that knows what's next).
/// A brief full-art splash covers launch, then fades into the map.
struct RootView: View {
    @State private var showSplash = Art.exists("splash")
        // Demo/verify launches jump straight in — no splash delaying screenshots.
        && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-autostart") || $0.hasPrefix("-demo") })

    var body: some View {
        ZStack {
            MapView()
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .onAppear {
            guard showSplash else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
    }
}

/// Full-bleed title art. Contained fill (see WorldBackdrop) so odd aspect
/// ratios crop the edges instead of inflating layout; tap skips early.
private struct SplashView: View {
    var body: some View {
        Color.black
            .overlay(Image("splash").resizable().scaledToFill())
            .clipped()
            .ignoresSafeArea()
            .accessibilityLabel("Multiplication Adventure")
    }
}
