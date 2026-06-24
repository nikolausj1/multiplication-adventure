import SwiftUI
import SwiftData

@main
struct LevelUpMathApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Fact.self, Profile.self, SessionRecord.self, MilestoneRecord.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        // Seed the fact universe and profile on first launch.
        LearningService(context: container.mainContext).bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.Color.primary)
        }
        .modelContainer(container)
    }
}
