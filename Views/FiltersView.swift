import SwiftUI
import SwiftData

/// Filters catalog — Todoist-style smart filters (Priority 1, Overdue, Today,
/// Next 7 days, No date). v1 is read-only: tapping a row pushes a filtered
/// list of open tasks; there is no query builder yet.
struct FiltersView: View {
    /// All open (uncompleted) tasks. Single source for count badges; the
    /// pushed result view runs its own `@Query` to pick up live edits.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    var body: some View {
        NavigationStack {
            List {
                ForEach(FilterKind.allCases) { kind in
                    filterRow(kind)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(TK.grouped)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: FilterKind.self) { kind in
                FilterResultView(kind: kind)
            }
        }
    }

    // MARK: - Row

    /// One filter row: leading tinted icon, title, trailing count badge.
    /// Tap pushes a `FilterResultView` for the chosen kind.
    @ViewBuilder
    private func filterRow(_ kind: FilterKind) -> some View {
        NavigationLink(value: kind) {
            HStack(spacing: 14) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(kind.iconTint)
                    .frame(width: 22)
                Text(kind.title)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                Spacer(minLength: 8)
                let n = count(for: kind)
                if n > 0 {
                    Text("\(n)")
                        .font(TK.subhead)
                        .foregroundStyle(TK.secondary)
                        .monospacedDigit()
                        .accessibilityLabel("\(n) tasks")
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(kind.accessibilityID)
        .accessibilityLabel(kind.title)
    }

    // MARK: - Counts

    private func count(for kind: FilterKind) -> Int {
        switch kind {
        case .priority1: return priority1Count
        case .overdue:   return overdueCount
        case .today:     return todayCount
        case .next7Days: return next7DaysCount
        case .noDate:    return noDateCount
        }
    }

    /// Open tasks flagged with the red p1 priority.
    private var priority1Count: Int {
        openTasks.reduce(into: 0) { $0 += $1.priority == 1 ? 1 : 0 }
    }

    /// Open tasks whose due date is strictly before the start of today.
    private var overdueCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return openTasks.reduce(into: 0) { acc, t in
            guard let due = t.dueDate else { return }
            if due < startOfToday { acc += 1 }
        }
    }

    /// Open tasks due any time today.
    private var todayCount: Int {
        openTasks.reduce(into: 0) { acc, t in
            guard let due = t.dueDate else { return }
            if Calendar.current.isDateInToday(due) { acc += 1 }
        }
    }

    /// Open tasks due in the next 7 days, inclusive of today.
    private var next7DaysCount: Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        guard let horizon = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return 0 }
        return openTasks.reduce(into: 0) { acc, t in
            guard let due = t.dueDate else { return }
            if due >= startOfToday && due < horizon { acc += 1 }
        }
    }

    /// Open tasks with no due date set.
    private var noDateCount: Int {
        openTasks.reduce(into: 0) { $0 += $1.dueDate == nil ? 1 : 0 }
    }
}

// MARK: - Filter kinds

/// Built-in smart filters surfaced by `FiltersView`. `Hashable` + `Identifiable`
/// so it can drive `NavigationLink(value:)` and `ForEach` directly.
enum FilterKind: String, CaseIterable, Identifiable, Hashable {
    case priority1
    case overdue
    case today
    case next7Days
    case noDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .priority1: "Priority 1"
        case .overdue:   "Overdue"
        case .today:     "Today"
        case .next7Days: "Next 7 days"
        case .noDate:    "No date"
        }
    }

    var iconName: String {
        switch self {
        case .priority1: "flag.fill"
        case .overdue:   "exclamationmark.circle"
        case .today:     "sun.max"
        case .next7Days: "calendar"
        case .noDate:    "calendar.badge.minus"
        }
    }

    var iconTint: Color {
        switch self {
        case .priority1: TK.priority(1)
        case .overdue:   TK.accent
        case .today:     TK.accent
        case .next7Days: TK.ink
        case .noDate:    TK.secondary
        }
    }

    var accessibilityID: String {
        switch self {
        case .priority1: "filter-priority1"
        case .overdue:   "filter-overdue"
        case .today:     "filter-today"
        case .next7Days: "filter-next7days"
        case .noDate:    "filter-nodate"
        }
    }
}

// MARK: - Filter result

/// Pushed onto the stack when a filter row is tapped. Shows every open task
/// that matches the chosen `FilterKind`, sorted by priority then due date.
struct FilterResultView: View {
    let kind: FilterKind
    @Query private var tasks: [TodoTask]

    var body: some View {
        Group {
            if filtered.isEmpty {
                empty
            } else {
                TaskListView(tasks: filtered, header: nil)
            }
        }
        .background(TK.canvas)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.large)
    }

    /// Open tasks matching the filter, sorted priority asc then due date asc.
    private var filtered: [TodoTask] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        let horizon = cal.date(byAdding: .day, value: 7, to: startOfToday) ?? .now
        return tasks
            .filter { task in
                guard !task.isCompleted else { return false }
                switch kind {
                case .priority1: return task.priority == 1
                case .overdue:
                    guard let due = task.dueDate else { return false }
                    return due < startOfToday
                case .today:
                    guard let due = task.dueDate else { return false }
                    return cal.isDateInToday(due)
                case .next7Days:
                    guard let due = task.dueDate else { return false }
                    return due >= startOfToday && due < horizon
                case .noDate:
                    return task.dueDate == nil
                }
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
    }

    @ViewBuilder
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(TK.secondary)
            Text(emptyTitle)
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text(emptySubtitle)
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
    }

    private var emptyTitle: String {
        switch kind {
        case .priority1: "No priority 1 tasks"
        case .overdue:   "Nothing overdue"
        case .today:     "No tasks due today"
        case .next7Days: "Nothing in the next 7 days"
        case .noDate:    "Everything has a date"
        }
    }

    private var emptySubtitle: String {
        switch kind {
        case .priority1: "Tasks with the red flag will show up here."
        case .overdue:   "You're all caught up."
        case .today:     "Plan your day by adding a task with today's date."
        case .next7Days: "No tasks scheduled for the coming week."
        case .noDate:    "Tasks without a due date will show up here."
        }
    }
}


