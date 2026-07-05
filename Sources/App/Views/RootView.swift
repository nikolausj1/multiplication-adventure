import SwiftUI
import SwiftData

/// The app root — the adventure map is the home/hub (§3/§6: the child never picks
/// what to study; one tap on the current world starts a session that knows what's next).
/// A brief full-art splash covers launch; first run (or after "Start over") the
/// onboarding flow sits between splash and map until the profile is set up.
struct RootView: View {
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var showSplash = Art.exists("splash")
        // Demo/verify launches jump straight in — no splash delaying screenshots.
        && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-autostart") || $0.hasPrefix("-demo") })

    private var needsOnboarding: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-autostartOnboarding") { return !(activeProfiles.first?.onboarded ?? false) }
        // Other demo/verify launches skip the first-run gate entirely.
        let skip = args.contains { ($0.hasPrefix("-autostart") && $0 != "-autostartOnboarding") || $0.hasPrefix("-demo") }
        if skip { return false }
        return !(activeProfiles.first?.onboarded ?? true)
    }

    var body: some View {
        ZStack {
            MapView()
            if needsOnboarding {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(10)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.5), value: needsOnboarding)
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
