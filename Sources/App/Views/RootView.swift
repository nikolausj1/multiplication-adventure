import SwiftUI

/// The app root — the adventure map is the home/hub (§3/§6: the child never picks
/// what to study; one tap on the current world starts a session that knows what's next).
struct RootView: View {
    var body: some View { MapView() }
}
