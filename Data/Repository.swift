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
        if task.isCompleted {
            NotificationManager.shared.cancel(taskID: task.id)
        } else {
            NotificationManager.shared.schedule(for: task)
        }
        SnapshotWriter.refresh(context: context)
    }

    static func delete(_ task: TodoTask, in context: ModelContext) {
        NotificationManager.shared.cancel(taskID: task.id)
        context.delete(task)
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    static func add(_ title: String, project: Project?, due: Date?, priority: Int, in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<TodoTask>())) ?? 0
        let t = TodoTask(title: title, dueDate: due, priority: priority, order: count, project: project)
        context.insert(t)
        try? context.save()
        NotificationManager.shared.schedule(for: t)
        SnapshotWriter.refresh(context: context)
    }

    /// Persist a new display order for `tasks`. Each task's `order` is set to
    /// its position in the array, so the next render (sorted by `order`) shows
    /// the same sequence. Caller is responsible for scoping `tasks` to the
    /// bucket being reordered (e.g. one section in a sectioned list) so tasks
    /// in other views are not renumbered.
    static func reorder(_ tasks: [TodoTask], in context: ModelContext) {
        for (i, t) in tasks.enumerated() {
            t.order = i
        }
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    /// Re-evaluate the local notification for `task` after a direct property
    /// edit (e.g. the user changed the due date or time in the detail view,
    /// which mutates the model in place). Schedules, cancels, or replaces
    /// the pending request to match the task's current `notifyAt`.
    static func reschedule(_ task: TodoTask, in context: ModelContext) {
        try? context.save()
        NotificationManager.shared.schedule(for: task)
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
