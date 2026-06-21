import Foundation
import SwiftData

/// A single to-do item. SwiftData persists this to on-device SQLite automatically.
@Model
final class TodoTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var createdAt: Date
    /// Wall-clock moment of the most recent write to any field on this task.
    /// Bumped by `Repository` on every mutation (toggle / add / edit / delete
    /// is a no-op for the dead task but every other write touches it).
    /// `SyncClient` uses this for last-write-wins conflict resolution.
    var updatedAt: Date
    /// Archived tasks are hidden from every default view (Today / Upcoming /
    /// Inbox / Project) and surface only in the Archive screen. Distinct
    /// from `isCompleted` — a completed task is "done"; an archived task is
    /// "out of sight". Todoist semantics.
    var isArchived: Bool
    var dueDate: Date?
    /// Optional reminder time-of-day for a local notification. Only the
    /// hour/minute components are meaningful — the date is taken from
    /// `dueDate`. `nil` means "no reminder". When both are set and the task
    /// is incomplete, `NotificationManager` fires a local notification at
    /// `dueDate` at the chosen hour/minute.
    var dueTime: Date?
    var completedAt: Date?
    /// 1 = highest (red) … 4 = none. Matches Todoist priority semantics.
    var priority: Int
    var order: Int
    var project: Project?
    /// Optional sub-grouping within the project — Todoist's "section" feature.
    /// `nil` means the task is at the top level of its project.
    var section: TaskSection?
    var labels: [Label] = []
    @Relationship(deleteRule: .cascade, inverse: \Subtask.task) var subtasks: [Subtask] = []
    /// Recurrence rule kind, encoded as a raw string for SwiftData portability.
    /// `nil` means the task is a one-off. One of `"daily"`, `"weekly"`,
    /// `"monthly"`, `"yearly"` (see `RecurrenceKind`). The next occurrence
    /// is computed by adding one unit to `dueDate`.
    var recurrence: String?
    /// ID of the parent task this instance was spawned from. `nil` on the
    /// original task and on one-off tasks. Lets the UI group historical /
    /// future instances of the same series.
    var recurrenceParentID: UUID?
    /// Hard deadline (separate from `dueDate`, which is the planned/scheduled
    /// point in time). `nil` means no hard deadline is set.
    var deadline: Date?
    /// Estimated effort in seconds. `nil` means duration is unknown.
    var duration: TimeInterval?
    /// Concrete start time when the user has slotted this task into their
    /// calendar. `nil` means the task is not on the schedule.
    var scheduledAt: Date?
    /// Free-form recurrence rule string (e.g. an RRULE). `nil` means the task
    /// is a one-off. Distinct from `recurrence`, which is the simple
    /// daily/weekly/monthly/yearly kind.
    var recurrenceRule: String?
    @Relationship(deleteRule: .cascade, inverse: \Reminder.task) var reminders: [Reminder] = []

    var isCompleted: Bool { completedAt != nil }
    var isRecurring: Bool { recurrence != nil }

    /// Wall-clock moment a local notification should fire, or `nil` if no
    /// reminder is set. Combines the day from `dueDate` with the hour/minute
    /// from `dueTime`. Returns `nil` if either component is missing.
    var notifyAt: Date? {
        guard let day = dueDate, let time = dueTime else { return nil }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let comps = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: dayStart)
    }

    /// Next due date after a recurrence tick, or `nil` if this task is not
    /// recurring or has no `dueDate` to anchor the calculation. Adds one
    /// unit of the recurrence kind to the current `dueDate`.
    var nextDueDateAfterCompletion: Date? {
        guard let kind = recurrence, let base = dueDate else { return nil }
        let cal = Calendar.current
        switch kind {
        case "daily":   return cal.date(byAdding: .day, value: 1, to: base)
        case "weekly":  return cal.date(byAdding: .weekOfYear, value: 1, to: base)
        case "monthly": return cal.date(byAdding: .month, value: 1, to: base)
        case "yearly":  return cal.date(byAdding: .year, value: 1, to: base)
        default:        return nil
        }
    }

    init(
        title: String,
        note: String = "",
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        priority: Int = 4,
        order: Int = 0,
        project: Project? = nil,
        labels: [Label] = [],
        section: TaskSection? = nil,
        recurrence: String? = nil,
        recurrenceParentID: UUID? = nil,
        deadline: Date? = nil,
        duration: TimeInterval? = nil,
        scheduledAt: Date? = nil,
        recurrenceRule: String? = nil,
        reminders: [Reminder] = []
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
        self.isArchived = false
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.completedAt = nil
        self.priority = priority
        self.order = order
        self.project = project
        self.labels = labels
        self.section = section
        self.recurrence = recurrence
        self.recurrenceParentID = recurrenceParentID
        self.deadline = deadline
        self.duration = duration
        self.scheduledAt = scheduledAt
        self.recurrenceRule = recurrenceRule
        self.reminders = reminders
    }
}

/// Centralized enum for recurrence kinds so views and Repository don't all
/// reach for raw strings. Add a new case here AND its Calendar mapping in
/// `TodoTask.nextDueDateAfterCompletion` to introduce a new cadence.
enum RecurrenceKind: String, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var storageValue: String { rawValue }
    /// SF Symbol used in chips / pickers to telegraph cadence at a glance.
    var icon: String {
        switch self {
        case .daily:   return "sun.max"
        case .weekly:  return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .yearly:  return "calendar.circle"
        }
    }
}
