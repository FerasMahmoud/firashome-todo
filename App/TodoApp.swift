import SwiftUI
import SwiftData

@main
struct TodoApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([TodoTask.self, Project.self, Label.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.uk.firashome.todo")
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback: in-memory so the app never hard-crashes on a bad store.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }

        // Seed demo data for screenshots / first launch.
        if CommandLine.arguments.contains("--seed-demo") || ProcessInfo.processInfo.arguments.contains("--seed-demo") {
            Seed.wipeAndSeed(context: container.mainContext)
        } else {
            Seed.seedIfEmpty(context: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AuthManager())
        }
        .modelContainer(container)
    }
}
