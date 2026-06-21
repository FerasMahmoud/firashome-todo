import Foundation
import SwiftData

/// A sub-grouping inside a `Project` — Todoist's "section" feature. Lets a
/// user partition a project's tasks into named buckets (e.g. "Today",
/// "This week", "Backlog") without creating a new project.
///
/// A task is either un-sectioned (the default; `section == nil`) or assigned
/// to exactly one section. Deleting a section leaves its tasks intact in the
/// parent project and just clears their `section` reference (`.nullify`).
@Model
final class TaskSection {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Display order within the parent project. Lower numbers render first.
    var order: Int
    var project: Project?

    @Relationship(deleteRule: .nullify, inverse: \TodoTask.section)
    var tasks: [TodoTask] = []

    init(name: String, order: Int = 0, project: Project? = nil) {
        self.id = UUID()
        self.name = name
        self.order = order
        self.project = project
    }
}
