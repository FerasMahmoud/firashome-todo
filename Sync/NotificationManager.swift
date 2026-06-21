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
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    /// Tracks whether we've already asked the user this install. Avoids
    /// re-prompting on every app launch (the system stops showing the
    /// prompt after the first decision, but we skip the call entirely).
    private var hasRequested = false

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
