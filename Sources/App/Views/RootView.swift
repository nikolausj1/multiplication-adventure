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

    // Demo/verify launches suppress the first-run gate — but only until a
    // "Start over" re-arms it mid-session (state, not a constant, for that reason).
    @State private var gateSuppressed = ProcessInfo.processInfo.arguments
        .contains { ($0.hasPrefix("-autostart") && $0 != "-autostartOnboarding") || $0.hasPrefix("-demo") }

    private var needsOnboarding: Bool {
        if ProcessInfo.processInfo.arguments.contains("-autostartOnboarding") {
            return !(activeProfiles.first?.onboarded ?? false)
        }
        if gateSuppressed { return false }
        return !(activeProfiles.first?.onboarded ?? true)
    }

    /// After onboarding, the chosen avatar flies from the ready page to its
    /// home in the map's player chip (upper left).
    @State private var flightKey: String?

    var body: some View {
        ZStack {
            MapView()
            if needsOnboarding {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(10)
            }
            if let key = flightKey {
                AvatarFlight(key: key) { flightKey = nil }
                    .zIndex(15)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.5), value: needsOnboarding)
        .onAppear {
            // Screenshot hook (simulator verification only).
            if ProcessInfo.processInfo.arguments.contains("-demoFlight") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    flightKey = activeProfiles.first?.avatarSymbol ?? "avatar1"
                }
            }
            guard showSplash else { return }
            scheduleSplashDismiss()
        }
        .onChange(of: activeProfiles.first?.onboarded) { old, onboarded in
            // Onboarding just finished: the avatar flies to the player chip.
            if old == false, onboarded == true {
                flightKey = activeProfiles.first?.avatarSymbol
            }
            // "Start over" flips the active profile back to un-onboarded mid-session:
            // the whole first-run moment plays again — splash, then onboarding.
            guard onboarded == false else { return }
            gateSuppressed = false
            if Art.exists("splash") {
                showSplash = true
                scheduleSplashDismiss()
            }
        }
    }

    private func scheduleSplashDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
        }
    }
}

/// The onboarding-finale hand-off: the chosen avatar sails from the ready
/// page's hero spot to the player chip in the map's upper-left corner, so the
/// kid sees "that's me, and that's where I live now."
private struct AvatarFlight: View {
    let key: String
    let done: () -> Void
    @State private var arrived = false

    var body: some View {
        GeometryReader { geo in
            AvatarBadge(key: key, size: arrived ? 40 : 230)
                .shadow(color: .black.opacity(0.35), radius: arrived ? 3 : 14,
                        y: arrived ? 2 : 6)
                .position(arrived
                          ? CGPoint(x: 57, y: 64)   // the player chip's avatar
                          : CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.33))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).delay(0.15)) { arrived = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { done() }
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
