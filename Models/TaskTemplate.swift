import Foundation
import SwiftData

/// A saved task template — pre-fills `title`, `note`, and `priority` so a new
/// task can be spawned in one tap. `name` is the human label shown in the
/// template picker (e.g. "Weekly review").
@Model
final class TaskTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var title: String
    var note: String
    /// 1 = highest (red) … 4 = none. Matches Todoist priority semantics.
    var priority: Int

    init(name: String, title: String, note: String = "", priority: Int = 4) {
        self.id = UUID()
        self.name = name
        self.title = title
        self.note = note
        self.priority = priority
    }
}
