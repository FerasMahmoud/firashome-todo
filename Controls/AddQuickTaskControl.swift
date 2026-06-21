import AppIntents
import WidgetKit
import SwiftUI

// MARK: - AddQuickTaskIntent
//
// Minimal AppIntent invoked by the lock-screen / Control Center control.
// Runs in the extension process (does NOT open the app), so it does not
// touch SwiftData. The intent writes a "deferred quick-add" marker into
// the shared App Group; the main app consumes it on next foreground.
//
// ponytail: This is a Tier-2 stub. The real wiring (ModelContainer shared
// across targets, or an App Group UserDefaults queue the app drains) is
// intentionally out of scope. The intent is fully typed so the rest of
// the stack compiles standalone.

struct AddQuickTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Task"
    static var description = IntentDescription(
        "Adds a new task from the lock screen or Control Center."
    )
    // Required for ControlWidget actions: the intent must complete
    // without launching the host app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title", default: "")
    var taskTitle: String

    init() {}
    init(taskTitle: String) { self.taskTitle = taskTitle }

    func perform() async throws -> some IntentResult {
        // Suite is nil if the App Group entitlement isn't present on this
        // extension; writes are silent no-ops in that case. The Todo
        // app reads `pendingQuickAddTitle` on next foreground and inserts.
        let suite = UserDefaults(suiteName: "group.uk.firashome.todo")
        suite?.set(taskTitle, forKey: "pendingQuickAddTitle")
        suite?.set(Date().timeIntervalSince1970, forKey: "pendingQuickAddAt")
        return .result()
    }
}

// MARK: - AddQuickTaskControl
//
// Lock-screen / Control Center button. A single tap fires
// `AddQuickTaskIntent`. Uses `ControlWidgetButton` (not the stateful
// `ControlWidgetToggle`) because the action is idempotent — every tap
// queues another quick add.
//
// NOTE: ControlWidgets only surface on iOS 18+ and must be added to the
// lock screen / Control Center manually by the user. The full control
// surface may need a real device to validate end-to-end.

struct AddQuickTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "AddQuickTaskControl") {
            ControlWidgetButton(action: AddQuickTaskIntent()) {
                Label("Add Task", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Quick Add Task")
        .description("Adds a task without unlocking your phone.")
    }
}

// MARK: - Bundle

@main
struct TodoControlsBundle: ControlWidgetBundle {
    var body: some ControlWidget {
        AddQuickTaskControl()
    }
}
