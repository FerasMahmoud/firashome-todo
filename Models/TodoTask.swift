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
    var completedAt: Date?
    /// 1 = highest (red) … 4 = none. Matches Todoist priority semantics.
    var priority: Int
    var order: Int
    var project: Project?
    var labels: [Label] = []

    var isCompleted: Bool { completedAt != nil }

    init(
        title: String,
        note: String = "",
        dueDate: Date? = nil,
        priority: Int = 4,
        order: Int = 0,
        project: Project? = nil,
        labels: [Label] = []
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.createdAt = .now
        self.dueDate = dueDate
        self.completedAt = nil
        self.priority = priority
        self.order = order
        self.project = project
        self.labels = labels
    }
}
