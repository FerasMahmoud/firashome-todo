import Foundation
import SwiftData
import UserNotifications

/// Local notification scheduling for tasks. One notification per task,
/// identified by the task's UUID. Scheduled when a task has both `dueDate`
/// and `dueTime` set and is not completed; cancelled when the task is
/// completed, deleted, or its reminder is cleared.
///
/// Tier-1: UNCalendarNotificationTrigger at `task.notifyAt`. No category
/// actions, no rich content, no sound customization — just the system
/// default banner + sound.
///
/// Tier-2 #34: registers a `UNNotificationCategory` ("TASK_REMINDER") with
/// `Complete` + `Snooze 30 min` actions, and a static delegate that
/// responds to taps. Snooze re-schedules 30 min from the tap moment using
/// the original content.
final class NotificationManager {
    static let shared = NotificationManager()

    /// Called once on first singleton access. Registers the notification
    /// category and assigns the static delegate. Must run before the first
    /// `add(_:)` so the actions render on the banner / lock screen.
    private init() {
        setupCategories()
        center.delegate = Self.delegate
    }

    private let center = UNUserNotificationCenter.current()
    /// Tracks whether we've already asked the user this install. Avoids
    /// re-prompting on every app launch (the system stops showing the
    /// prompt after the first decision, but we skip the call entirely).
    private var hasRequested = false

    // MARK: - Category + actions (Tier-2 #34)

    /// Category identifier stamped on every scheduled `UNNotificationContent`.
    /// The system only shows `Complete` / `Snooze` on a banner whose content
    /// carries this identifier AND whose category is registered (see
    /// `setupCategories`).
    static let categoryIdentifier = "TASK_REMINDER"

    /// Action identifiers — referenced from the delegate's response switch.
    enum ActionID {
        static let complete = "TASK_REMINDER_COMPLETE"
        static let snooze   = "TASK_REMINDER_SNOOZE"
    }

    /// How far a SNOOZE tap pushes the next reminder. 30 minutes per spec.
    static let snoozeInterval: TimeInterval = 30 * 60

    /// Register the category + its two actions on the system. Called once
    /// from `init`. `authenticationRequired` on Complete means iOS will
    /// only fire the action after the device is unlocked — keeps a casual
    /// lock-screen tap from marking a task done.
    private func setupCategories() {
        let complete = UNNotificationAction(
            identifier: ActionID.complete,
            title: "Complete",
            options: [.authenticationRequired]
        )
        let snooze = UNNotificationAction(
            identifier: ActionID.snooze,
            title: "Snooze 30 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Delegate (Tier-2 #34)

    /// Static, stateless delegate. Handles user taps on the banner's
    /// Complete / Snooze actions.
    ///
    /// **Limitation — ModelContext is not reachable here.** The SwiftData
    /// `ModelContext` is main-actor bound and the delegate callbacks fire
    /// on a background queue with no injected container. So a COMPLETE
    /// tap only **cancels the notification** and removes the delivered
    /// banner — it does NOT toggle `TodoTask.completedAt`. Toggling
    /// completion still requires opening the app and using the row swipe
    /// / tap gesture. Upgrade path: capture `ModelContainer` in
    /// `NotificationManager.init`, hand a fresh `ModelContext(container)`
    /// to the delegate, hop to `@MainActor`, and call
    /// `Repository.toggle(...)` from `didReceive`.
    /// ponytail: ceiling = no SwiftData write from background delegate;
    /// upgrade = own ModelContainer + MainActor hop.
    private static let delegate = TaskActionDelegate()

    private final class TaskActionDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            // Surface the banner + sound even when the app is foregrounded
            // — a reminder that vanishes the moment the user opens the app
            // defeats the purpose.
            completionHandler([.banner, .sound, .list])
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            let request = response.notification.request
            let originalID = request.identifier
            let content = request.content

            switch response.actionIdentifier {
            case ActionID.complete:
                // Drop the pending schedule + the delivered banner. Does
                // NOT toggle the task in SwiftData — see limitation note
                // on `delegate` above.
                center.removePendingNotificationRequests(withIdentifiers: [originalID])
                center.removeDeliveredNotifications(withIdentifiers: [originalID])

            case ActionID.snooze:
                // Remove the delivered banner so the user doesn't see both
                // the original and the snoozed copy, then schedule a fresh
                // copy of the same content 30 min from now. The new
                // request's identifier carries a timestamp so multiple
                // snoozes on the same task don't collide on the original
                // UUID.
                center.removeDeliveredNotifications(withIdentifiers: [originalID])
                let fireAt = Date().addingTimeInterval(NotificationManager.snoozeInterval)
                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireAt
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let snoozeRequest = UNNotificationRequest(
                    identifier: "\(originalID).snooze.\(Int(fireAt.timeIntervalSince1970))",
                    content: content,
                    trigger: trigger
                )
                center.add(snoozeRequest, withCompletionHandler: nil)

            default:
                // Plain tap (no action) — leave pending + delivered state
                // alone; the app will foreground and the user can act.
                break
            }

            completionHandler()
        }
    }

    // MARK: - Existing API (unchanged)

    /// Request alert + sound permission. Safe to call multiple times — only
    /// the first call hits the system. Non-blocking.
    func requestPermissionIfNeeded() {
        guard !hasRequested else { return }
        hasRequested = true
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Result is best-effort: if denied, schedule() becomes a no-op.
        }
    }

    /// Returns the current authorization status. Useful for UI state.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedule (or replace) the notification for `task`. If the task has no
    /// reminder moment (`notifyAt` nil), or the moment is in the past, or
    /// the task is completed, this is a no-op after cancelling any existing
    /// request for this task.
    func schedule(for task: TodoTask) {
        let id = task.id.uuidString
        cancel(taskID: task.id)

        guard !task.isCompleted, let fireAt = task.notifyAt, fireAt > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = task.title
        if let project = task.project {
            content.body = project.name
        } else if !task.note.isEmpty {
            content.body = task.note
        } else {
            content.body = "Due now"
        }
        content.sound = .default
        content.threadIdentifier = "task"
        // Tier-2 #34: tie this notification to the registered category so
        // the system renders the Complete / Snooze actions on the banner.
        content.categoryIdentifier = Self.categoryIdentifier

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Cancel the pending notification for a task, if any.
    func cancel(taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
    }

    /// Cancel every pending notification we ever scheduled. Used by the
    /// "Reset demo data" flow so seed data doesn't leave dangling reminders.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Walk the store and schedule a notification for every incomplete task
    /// that has both a due date and a time. Call this on app launch and when
    /// the scene becomes active — the system clears pending notifications
    /// across device restarts, and this rebuilds them.
    func rescheduleAll(context: ModelContext) {
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate<TodoTask> { $0.completedAt == nil }
        )
        let tasks = (try? context.fetch(descriptor)) ?? []
        for task in tasks {
            schedule(for: task)
        }
    }
}
