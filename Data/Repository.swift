import Foundation
import SwiftData

/// Small, intent-revealing helpers over the ModelContext.
enum Repository {
    static func toggle(_ task: TodoTask, in context: ModelContext) {
        let willComplete = !task.isCompleted
        if willComplete {
            task.completedAt = .now
        } else {
            task.completedAt = nil
        }
        task.updatedAt = .now
        try? context.save()
        if task.isCompleted {
            NotificationManager.shared.cancel(taskID: task.id)
        } else {
            NotificationManager.shared.schedule(for: task)
        }
        // Recurring: completing a recurring task also spawns the next open
        // occurrence one unit out. Uncompleting never spawns anything (the
        // next instance may already exist from a prior completion).
        if willComplete, task.isRecurring, let nextDue = task.nextDueDateAfterCompletion {
            spawnNextOccurrence(of: task, due: nextDue, in: context)
        }
        SnapshotWriter.refresh(context: context)
    }

    static func delete(_ task: TodoTask, in context: ModelContext) {
        NotificationManager.shared.cancel(taskID: task.id)
        context.delete(task)
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    /// Move a task into the archive. Archived tasks stay in the store (so the
    /// Archive screen can list them and undo is one tap away) but are hidden
    /// from Today / Upcoming / Inbox / Project / Search. Idempotent — calling
    /// on an already-archived task just bumps `updatedAt`.
    static func archive(_ task: TodoTask, in context: ModelContext) {
        task.isArchived = true
        task.updatedAt = .now
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    /// Restore an archived task. No-op when the task is not archived.
    static func unarchive(_ task: TodoTask, in context: ModelContext) {
        guard task.isArchived else { return }
        task.isArchived = false
        task.updatedAt = .now
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    /// Insert a new task and return it so the caller can attach side-channel
    /// state (e.g. a `Reminder`) in the same call site. `recurrence` is the
    /// simple kind string (`"daily"` / `"weekly"` / …) and maps to
    /// `TodoTask.recurrence`; `recurrenceRule` is the free-form RRULE and
    /// maps to `TodoTask.recurrenceRule`. `labels` is assigned to the task's
    /// `labels` relationship.
    @discardableResult
    static func add(
        _ title: String,
        project: Project?,
        due: Date?,
        priority: Int,
        recurrence: String? = nil,
        recurrenceRule: String? = nil,
        labels: [Label] = [],
        in context: ModelContext
    ) -> TodoTask {
        let count = (try? context.fetchCount(FetchDescriptor<TodoTask>())) ?? 0
        let t = TodoTask(
            title: title,
            dueDate: due,
            priority: priority,
            order: count,
            project: project,
            labels: labels,
            recurrence: recurrence,
            recurrenceRule: recurrenceRule
        )
        t.updatedAt = .now
        context.insert(t)
        try? context.save()
        NotificationManager.shared.schedule(for: t)
        SnapshotWriter.refresh(context: context)
        return t
    }

    /// Persist a new display order for `tasks`. Each task's `order` is set to
    /// its position in the array, so the next render (sorted by `order`) shows
    /// the same sequence. Caller is responsible for scoping `tasks` to the
    /// bucket being reordered (e.g. one section in a sectioned list) so tasks
    /// in other views are not renumbered.
    static func reorder(_ tasks: [TodoTask], in context: ModelContext) {
        let now = Date.now
        for (i, t) in tasks.enumerated() {
            t.order = i
            t.updatedAt = now
        }
        try? context.save()
        SnapshotWriter.refresh(context: context)
    }

    /// Re-evaluate the local notification for `task` after a direct property
    /// edit (e.g. the user changed the due date or time in the detail view,
    /// which mutates the model in place). Schedules, cancels, or replaces
    /// the pending request to match the task's current `notifyAt`.
    static func reschedule(_ task: TodoTask, in context: ModelContext) {
        task.updatedAt = .now
        try? context.save()
        NotificationManager.shared.schedule(for: task)
    }

    /// Move a task into a different `Section` (or un-section it by passing
    /// `nil`). Persists the relation change and refreshes the widget snapshot
    /// so the move is reflected everywhere immediately. Caller is responsible
    /// for skipping the call when the task is already in the destination
    /// (the board view guards on `task.section?.id != section?.id`).
    static func setSection(_ task: TodoTask, to section: TaskSection?, in context: ModelContext) {
        task.section = section
        task.updatedAt = .now
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

    /// All archived tasks, newest-first by `updatedAt`. Powers the Archive
    /// screen — distinct from completed (Completed = `completedAt != nil`,
    /// Archive = `isArchived == true`; a task can be both).
    static func archivedTasks(in context: ModelContext) -> [TodoTask] {
        let d = FetchDescriptor<TodoTask>(
            predicate: #Predicate<TodoTask> { t in t.isArchived == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(d)) ?? []
    }

    /// Spawn the next open occurrence of a recurring task after the current
    /// instance is completed. Copies the editable fields (title / note /
    /// project / labels / section / priority / time / recurrence rule) and
    /// stamps the new due date. Subtasks are intentionally NOT copied — each
    /// occurrence starts with a fresh checklist.
    static func spawnNextOccurrence(of task: TodoTask, due: Date, in context: ModelContext) {
        let next = TodoTask(
            title: task.title,
            note: task.note,
            dueDate: due,
            dueTime: task.dueTime,
            priority: task.priority,
            order: task.order,
            project: task.project,
            labels: task.labels,
            section: task.section,
            recurrence: task.recurrence,
            recurrenceParentID: task.recurrenceParentID ?? task.id
        )
        context.insert(next)
        try? context.save()
        NotificationManager.shared.schedule(for: next)
    }
}
