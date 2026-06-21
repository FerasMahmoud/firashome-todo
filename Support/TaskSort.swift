import Foundation

/// Pure, intent-revealing sort helpers over `[TodoTask]`.
///
/// Each view used to inline its own comparator — copies drifted (some added a
/// `createdAt` tiebreaker, some used `.distantFuture`, some used `.distantPast`)
/// and the same logic got re-typed per file. `TaskSort` is the single place
/// those comparators live now, so every screen shows tasks in the same order
/// for the same intent ("priority first, then manual order", "by due date,
/// then order", etc.).
///
/// All helpers are non-mutating and `O(n log n)` (Foundation's Timsort via
/// `sorted(by:)`); they do not touch the model context or fire side effects.
enum TaskSort {

    // MARK: - Open-task orderings

    /// Priority ascending (P1 first), then manual `order` ascending, then
    /// `createdAt` ascending as the final stable tiebreaker so two tasks that
    /// share priority + order still render in a deterministic order across
    /// reloads. The default for open lists in Inbox / Today / Upcoming /
    /// Calendar / Project / Filter results.
    static func byPriorityThenOrder(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// Priority ascending, then earliest `dueDate` ascending. Tasks with no
    /// due date sort to the end of each priority tier. Used by
    /// `FilterResultView` where an undated P3 task should never out-rank a
    /// dated P3 task just because it has no date.
    static func byPriorityThenDueDate(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return dueOrDistantFuture(lhs) < dueOrDistantFuture(rhs)
        }
    }

    /// Earliest `dueDate` ascending (undated tasks sort to the end), then
    /// manual `order`. Used by Today-overdue (the due date IS the ordering
    /// signal — most-overdue first) and by the Board lanes (most-urgent card
    /// on top of each lane).
    static func byDueDateThenOrder(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { lhs, rhs in
            let l = dueOrDistantFuture(lhs)
            let r = dueOrDistantFuture(rhs)
            if l != r { return l < r }
            return lhs.order < rhs.order
        }
    }

    // MARK: - Completed-task ordering

    /// Most-recently-completed first (`completedAt` descending). Tasks without
    /// `completedAt` sort to the end so an in-flight task never ranks above a
    /// just-finished one. Used by ProjectDetailView's "X completed" section
    /// and the activity feed.
    static func byCompletionRecency(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.sorted { lhs, rhs in
            completedOrDistantPast(lhs) > completedOrDistantPast(rhs)
        }
    }

    // MARK: - Nil-date sentinels

    /// `task.dueDate` or `.distantFuture` when nil. Used as the "undated tasks
    /// sort to the end" sentinel — `distantFuture` is the only date that's
    /// never an actual due date, so undated tasks naturally sink to the
    /// bottom of every ascending-due sort.
    private static func dueOrDistantFuture(_ task: TodoTask) -> Date {
        task.dueDate ?? .distantFuture
    }

    /// `task.completedAt` or `.distantPast` when nil. Mirrors
    /// `dueOrDistantFuture` but in the descending-completion direction:
    /// undated tasks sink to the end of a "most recently completed" list.
    private static func completedOrDistantPast(_ task: TodoTask) -> Date {
        task.completedAt ?? .distantPast
    }
}