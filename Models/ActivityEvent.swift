import Foundation
import SwiftData

/// An entry in the activity feed (created / completed / updated). Decoupled from
/// `TodoTask` via `taskTitle` + optional `projectID` so the feed survives task
/// deletion.
@Model
final class ActivityEvent {
    @Attribute(.unique) var id: UUID
    var kind: String
    var at: Date
    var taskTitle: String
    var projectID: UUID?

    init(kind: String, taskTitle: String, projectID: UUID? = nil) {
        self.id = UUID()
        self.kind = kind
        self.at = .now
        self.taskTitle = taskTitle
        self.projectID = projectID
    }
}