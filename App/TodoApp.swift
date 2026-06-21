import SwiftUI
import SwiftData

@main
struct TodoApp: App {
    let container: ModelContainer
    @AppStorage("onboarded") private var onboarded = false

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

        // Notification permission is requested AFTER onboarding completes
        // (see `OnboardingView.task(id: onboarded)`). Asking at launch would
        // pop the system prompt before the user knows what the app does,
        // so we defer until the tour is done.
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
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
