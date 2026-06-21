import Foundation
import SwiftData

@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var date: Date
    var task: TodoTask?

    init(date: Date) {
        id = UUID()
        self.date = date
    }
}