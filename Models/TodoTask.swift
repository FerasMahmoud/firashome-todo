import Foundation
import SwiftData

/// A single to-do item. SwiftData persists this to on-device SQLite automatically.
@Model
final class TodoTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var createdAt: Date
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

    var isCompleted: Bool { completedAt != nil }

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

    init(
        title: String,
        note: String = "",
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        priority: Int = 4,
        order: Int = 0,
        project: Project? = nil,
        labels: [Label] = [],
        section: TaskSection? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.createdAt = .now
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.completedAt = nil
        self.priority = priority
        self.order = order
        self.project = project
        self.labels = labels
        self.section = section
    }
}
