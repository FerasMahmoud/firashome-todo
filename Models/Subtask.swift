import Foundation
import SwiftData

/// A checklist step inside a Task — turns a flat to-do into a checklist ("more than to-do").
@Model
final class Subtask {
    @Attribute(.unique) var id: UUID
    var title: String
    var isDone: Bool
    var order: Int
    var task: TodoTask?

    init(title: String, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.order = order
    }
}
