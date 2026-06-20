import Foundation
import SwiftData

/// Recomputes today/overdue counts from the store and pushes them to the
/// App Group so the home-screen widget + Dynamic Island can render them.
enum SnapshotWriter {
    static func refresh(context: ModelContext) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: start)!

        let all = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
        let incomplete = all.filter { $0.completedAt == nil }

        let overdue = incomplete.filter { ($0.dueDate ?? .distantFuture) < start }
        let today = incomplete.filter {
            guard let d = $0.dueDate else { return false }
            return d >= start && d < tomorrow
        }

        let next = incomplete
            .filter { ($0.dueDate ?? .distantFuture) >= start }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .first

        SnapshotStore.save(WidgetSnapshot(
            todayCount: today.count,
            overdueCount: overdue.count,
            nextTaskTitle: next?.title,
            updatedAt: .now
        ))
    }
}
