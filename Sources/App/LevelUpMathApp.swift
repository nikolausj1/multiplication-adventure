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
        else if args.contains("-demoGoldenEra") { service.applyDemoGoldenEra() }
        else if args.contains("-demoProgress") { service.applyDemoProgress(complete: false) }
        if args.contains("-forceTrueFalse") { LearningService.trueFalseDenominator = 1 }
        if let i = args.firstIndex(of: "-starsGoal"), i + 1 < args.count, let n = Int(args[i + 1]) {
            service.setStarsPerWorldGoal(n)   // simulator verification only
        }
        // Golden Guardians (phase 3): force a gilded-worlds bitmask on top of
        // whatever demo seeding ran above — e.g. `-demoGoldenEra -gildWorlds 127`
        // for all seven gold. Simulator verification only.
        if let i = args.firstIndex(of: "-gildWorlds"), i + 1 < args.count, let n = Int(args[i + 1]) {
            service.setGildedWorldsMask(n)
        }
        // Visual redesign v2: pick which conquered-node treatment
        // (`ConqueredStyle`) to render for on-device comparison — 1 Crown,
        // 2 Sash, 3 Laurel. Defaults to Crown when absent, which is also
        // what every Release build renders (nothing outside this #if DEBUG
        // block ever touches `ConqueredStyle.current`). Simulator
        // verification only.
        #if DEBUG
        if let i = args.firstIndex(of: "-conqueredStyle"), i + 1 < args.count,
           let n = Int(args[i + 1]), let style = ConqueredStyle(rawValue: n) {
            ConqueredStyle.current = style
        }
        #endif
        if args.contains("-unlockLightning") {
            service.activeProfile().lightningRoundUnlocked = true   // simulator verification only
            try? container.mainContext.save()
        }
        MainActor.assumeIsolated {
            QuestPlanDump.runIfRequested()
            GoldenSimDump.runIfRequested()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.Color.primary)
        }
        .modelContainer(container)
    }
}
