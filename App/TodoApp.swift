import SwiftUI
import SwiftData

@main
struct TodoApp: App {
    let container: ModelContainer
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    init() {
        let schema = Schema([TodoTask.self, Project.self, Label.self, Subtask.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
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

        // Ask for local-notification permission the first time the app
        // launches. iOS only shows the system prompt once per install —
        // subsequent calls are no-ops, so re-launches are safe.
        NotificationManager.shared.requestPermissionIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(AuthManager())
        }
        .modelContainer(container)
    }
}
