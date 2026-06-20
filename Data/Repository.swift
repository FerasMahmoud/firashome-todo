import Foundation
import SwiftData

/// Small, intent-revealing helpers over the ModelContext.
enum Repository {
    static func toggle(_ task: TodoTask, in context: ModelContext) {
        if task.isCompleted {
            task.completedAt = nil
        } else {
            task.completedAt = .now
        }
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    static func delete(_ task: TodoTask, in context: ModelContext) {
        context.delete(task)
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    static func add(_ title: String, project: Project?, due: Date?, priority: Int, in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<TodoTask>())) ?? 0
        let t = TodoTask(title: title, dueDate: due, priority: priority, order: count, project: project)
        context.insert(t)
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    static func tasks(dueOn day: Date, in context: ModelContext) -> [TodoTask] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let d = FetchDescriptor<TodoTask>(
            predicate: #Predicate<TodoTask> { t in
                (t.completedAt == nil) && (t.dueDate != nil) && (t.dueDate! >= start) && (t.dueDate! < end)
            },
            sortBy: [SortDescriptor(\.order)]
        )
        return (try? context.fetch(d)) ?? []
    }
}
