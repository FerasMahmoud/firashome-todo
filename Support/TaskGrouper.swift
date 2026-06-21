import Foundation
import SwiftData

/// Pure, intent-revealing groupers over `[TodoTask]`.
///
/// Each view used to inline its own bucketing (day-buckets for Upcoming /
/// Calendar, priority-lanes for the Board, section-buckets for Project
/// detail). `TaskGrouper` centralizes the bucketing so the "what's a day?"
/// or "how do we order the lanes?" decisions live in one place rather than
/// being copy-pasted with subtle drift.
///
/// All helpers are non-mutating and read-only — they don't insert / delete /
/// mutate tasks. The result is in display order, suitable for direct `ForEach`
/// in the view that consumes it.
enum TaskGrouper {

    // MARK: - Day buckets

    /// Tasks whose `dueDate` falls within `[start, end)`, bucketed by
    /// `Calendar.current.startOfDay`. The returned array is in chronological
    /// order (oldest day first); within each day tasks are sorted by
    /// `TaskSort.byPriorityThenOrder` so every day reads the same way the
    /// user already sees elsewhere. Tasks without a `dueDate` are dropped
    /// silently — they have no day to live in.
    ///
    /// `calendar` defaults to `.current`; pass an explicit value in tests.
    static func byDay(
        _ tasks: [TodoTask],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [(date: Date, tasks: [TodoTask])] {
        let inWindow = tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due >= start && due < end
        }
        let grouped = Dictionary(grouping: inWindow) { task in
            calendar.startOfDay(for: task.dueDate ?? .now)
        }
        return grouped.keys.sorted().map { day in
            (date: day, tasks: TaskSort.byPriorityThenOrder(grouped[day] ?? []))
        }
    }

    // MARK: - Priority lanes

    /// Open tasks bucketed into the four priority lanes (P1 → P4) in display
    /// order — the most urgent lane is first, matching the left-to-right
    /// mental model every other priority-aware view uses. Completed tasks
    /// are filtered out (the Board only shows open work). Tasks whose
    /// priority is outside 1…4 are dropped — every model shipped clamps to
    /// that range. Within each lane tasks are sorted by
    /// `TaskSort.byDueDateThenOrder` so the most-urgent card sits on top.
    static func byPriorityLane(_ tasks: [TodoTask]) -> [(priority: Int, tasks: [TodoTask])] {
        let open = tasks.filter { !$0.isCompleted }
        return [1, 2, 3, 4].map { p in
            (priority: p, tasks: TaskSort.byDueDateThenOrder(open.filter { $0.priority == p }))
        }
    }

    // MARK: - Project sections

    /// Open tasks in a single project, bucketed into "un-sectioned" first
    /// and then each `TaskSection` in the project's declared `order`. The
    /// un-sectioned bucket is named after the project so its header reads
    /// like the project's top-level group; each section bucket uses the
    /// section's own `name`. Empty buckets are omitted so a section with no
    /// open tasks doesn't render as a hollow header.
    ///
    /// `tasks` must already be scoped to one project + open — the helper
    /// trusts the caller (matches the `incompleteTasks` pre-filter in
    /// `ProjectDetailView`). `project` is only consulted for display names
    /// and the section list.
    static func byProjectSection(
        _ tasks: [TodoTask],
        in project: Project?
    ) -> [(id: String, name: String, tasks: [TodoTask])] {
        var groups: [(id: String, name: String, tasks: [TodoTask])] = []

        let unsectioned = tasks.filter { $0.section == nil }
        if !unsectioned.isEmpty {
            groups.append((
                id: Self.unsectionedID,
                name: project?.name ?? "",
                tasks: TaskSort.byPriorityThenOrder(unsectioned)
            ))
        }

        let sections = (project?.sections ?? []).sorted { $0.order < $1.order }
        for section in sections {
            let bucket = tasks.filter { $0.section?.id == section.id }
            guard !bucket.isEmpty else { continue }
            groups.append((
                id: section.id.uuidString,
                name: section.name,
                tasks: TaskSort.byPriorityThenOrder(bucket)
            ))
        }
        return groups
    }

    /// Sentinel id for the un-sectioned bucket, kept distinct from real
    /// section UUIDs so the consuming view can branch on it without an
    /// extra `nil` check on every render.
    static let unsectionedID = "__project__"
}