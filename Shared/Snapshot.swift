import Foundation

/// Tiny snapshot the widget + Dynamic Island read from the App Group.
/// App writes it on every change; widget reads it on timeline refresh.
struct WidgetSnapshot: Codable {
    var todayCount: Int
    var overdueCount: Int
    var nextTaskTitle: String?
    var updatedAt: Date

    static let empty = WidgetSnapshot(todayCount: 0, overdueCount: 0, nextTaskTitle: nil, updatedAt: .distantPast)
}

enum SnapshotStore {
    static let suiteName = "group.uk.firashome.todo"
    static let key = "widgetSnapshot"

    static func save(_ s: WidgetSnapshot) {
        UserDefaults(suiteName: suiteName)?.set(try? JSONEncoder().encode(s), forKey: key)
    }

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key),
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return s
    }
}
