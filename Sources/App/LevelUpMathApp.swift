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
        let service = LearningService(context: container.mainContext)
        service.bootstrap()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoComplete") { service.applyDemoProgress(complete: true) }
        else if args.contains("-demoMapDone") { service.applyDemoMapDone() }
        else if args.contains("-demoProgress") { service.applyDemoProgress(complete: false) }
        if args.contains("-forceTrueFalse") { LearningService.trueFalseDenominator = 1 }
        if let i = args.firstIndex(of: "-starsGoal"), i + 1 < args.count, let n = Int(args[i + 1]) {
            service.setStarsPerWorldGoal(n)   // simulator verification only
        }
        MainActor.assumeIsolated { QuestPlanDump.runIfRequested() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.Color.primary)
        }
        .modelContainer(container)
    }
}
