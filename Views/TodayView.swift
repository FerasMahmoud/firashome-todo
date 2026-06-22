import SwiftUI
import SwiftData

/// "Today" screen — Todoist-style list of open tasks due today or earlier.
///
/// Renders a large "Today" navigation title with today's date as a small
/// subtitle, then sections driven by the chosen `GroupMode`:
///   - `day`     — the original Overdue + Today split (the default).
///   - `priority` — P1 → P4 lanes, most-urgent first.
///   - `project` — one section per project + a "No project" bucket.
///
/// A toolbar Menu/Picker over `TaskSort` re-orders the rows within every
/// section. Both choices persist in AppStorage per view.
struct TodayView: View {
    /// All open (uncompleted) tasks. We bucket them into Overdue / Today in
    /// Swift rather than in the `#Predicate`, because date arithmetic in the
    /// predicate macro is awkward across SDKs and the data volume here is small.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    /// Tasks completed today (for the progress ring).
    @Query(filter: #Predicate<TodoTask> { $0.completedAt != nil })
    private var completedTasks: [TodoTask]

    @Environment(\.modelContext) private var ctx

    /// Persisted sort order. AppStorage so the choice survives across
    /// launches and is per-view (this key is Today-only).
    @AppStorage("today-sort-mode") private var sortMode: SortMode = .priorityOrder

    /// Persisted grouping mode. AppStorage; per-view key.
    @AppStorage("today-group-mode") private var groupMode: GroupMode = .day

    /// Display-only sort. Each case wraps one of the `TaskSort` helpers —
    /// the toolbar Picker drives this; `apply(_:)` re-sorts the displayed
    /// tasks within each section.
    private enum SortMode: String, CaseIterable, Identifiable {
        case priorityOrder
        case priorityDue
        case dueOrder

        var id: String { rawValue }

        var label: String {
            switch self {
            case .priorityOrder: return "Priority"
            case .priorityDue: return "Priority, then due date"
            case .dueOrder: return "Due date"
            }
        }

        var systemImage: String {
            switch self {
            case .priorityOrder: return "exclamationmark.circle"
            case .priorityDue: return "calendar.badge.clock"
            case .dueOrder: return "calendar"
            }
        }

        func apply(_ tasks: [TodoTask]) -> [TodoTask] {
            switch self {
            case .priorityOrder: return TaskSort.byPriorityThenOrder(tasks)
            case .priorityDue: return TaskSort.byPriorityThenDueDate(tasks)
            case .dueOrder: return TaskSort.byDueDateThenOrder(tasks)
            }
        }
    }

    /// Section shape for Today. `label == nil` renders a section with no
    /// header (the legacy "Today" section under the day group). `icon` and
    /// `tint` are optional so the priority/project headers can show a
    /// colour cue without forcing it on every section.
    private enum GroupMode: String, CaseIterable, Identifiable {
        case day
        case priority
        case project

        var id: String { rawValue }

        var label: String {
            switch self {
            case .day: return "Overdue / Today"
            case .priority: return "Priority"
            case .project: return "Project"
            }
        }

        var systemImage: String {
            switch self {
            case .day: return "calendar.day.timeline.left"
            case .priority: return "exclamationmark.3"
            case .project: return "folder"
            }
        }
    }

    /// One renderable section. `id` is stable across re-renders so the
    /// ForEach diff can identify which sections appear / disappear as the
    /// group mode changes — that's what makes the section transition fire.
    private struct DisplayBucket: Identifiable {
        let id: String
        let label: String?
        let tasks: [TodoTask]
        let icon: String?
        let tint: Color?
    }

    // Cached at init so the list view is cheap to recompute when the query
    // refreshes. `Date.now` and `Calendar.current` would otherwise re-evaluate
    // on every body invocation.
    private let startOfToday: Date
    private let startOfTomorrow: Date
    private let dateSubtitle: String

    init() {
        let cal = Calendar.current
        let now = Date.now
        let start = cal.startOfDay(for: now)
        self.startOfToday = start
        self.startOfTomorrow = cal.date(byAdding: .day, value: 1, to: start) ?? start

        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEE d MMM"
        self.dateSubtitle = f.string(from: now)
    }

    var body: some View {
        content
            .background(TK.canvas)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .environment(\.hideRedundantDue, true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    groupMenu
                }
            }
    }

    // MARK: - Toolbar menus

    /// Sort picker. The icon bounces on each change so the user gets a
    /// visible acknowledgement even when the new order looks the same.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .symbolEffect(.bounce, value: sortMode)
        }
        .accessibilityLabel("Sort order")
        .accessibilityIdentifier("today-sort-menu")
    }

    /// Group picker. The icon bounces on each change so the section
    /// re-shuffle is signalled in the toolbar even before the list
    /// re-renders the new sections.
    private var groupMenu: some View {
        Menu {
            Picker("Group by", selection: $groupMode) {
                ForEach(GroupMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
        } label: {
            Image(systemName: "square.grid.2x2")
                .symbolEffect(.bounce, value: groupMode)
        }
        .accessibilityLabel("Group by")
        .accessibilityIdentifier("today-group-menu")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let combined = overdue + todays
        if combined.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Date subtitle + task count — sits under the large "Today" nav title.
                // The whole text animates as the count changes (numericText
                // picks out the digits and tweens them). The .animation
                // modifier supplies the active transaction so the
                // contentTransition actually fires — without it the digits
                // snap.
                Text("\(dateSubtitle) · \(combined.count) tasks")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: combined.count)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("today-date-subtitle")

                // Glassy progress ring.
                ProgressRing(done: doneToday, total: todays.count + doneToday)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 14)

                taskList
            }
        }
    }

    private var taskList: some View {
        List {
            ForEach(displayedBuckets) { bucket in
                Section {
                    ForEach(bucket.tasks) { task in
                        TaskRowView(task: task)
                            .listRowSeparatorTint(TK.hairlineSoft)
                    }
                    .onMove { source, destination in
                        move(bucket.tasks, from: source, to: destination)
                    }
                } header: {
                    if let label = bucket.label {
                        HStack(spacing: 6) {
                            if let icon = bucket.icon {
                                Image(systemName: icon)
                                    .font(TK.sectionHeader)
                                    .foregroundStyle(bucket.tint ?? TK.secondary)
                                    .accessibilityHidden(true)
                            }
                            Text(label)
                                .font(TK.sectionHeader)
                                .foregroundStyle(bucket.tint ?? TK.secondary)
                        }
                        .textCase(nil)
                    }
                }
                // Section-level transition: when group mode changes and a
                // section appears or disappears, glide it in from the top
                // with an opacity fade. Same applies to any section whose
                // bucket identity changes between renders.
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)

        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)
        .background {
            if TK.isDarkGlass { PlanetLayer() } else { TK.canvas }
        }
        // Spring animation bound to the bucket count — covers task add /
        // remove from the underlying @Query. The .animation(value:) modifier
        // also propagates to the section transitions on group-mode change
        // because the section count is part of the bucket structure.
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sortMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: groupMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: displayedBuckets.count)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("You're all clear for today")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
                .multilineTextAlignment(.center)
            Text("Tap + to add a task")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-empty-state")
        .accessibilityLabel("You're all clear for today. Tap + to add a task.")
    }

    // MARK: - Reorder

    /// Drag-to-reorder within a bucket. Unified across all group modes
    /// (day, priority, project) — every bucket exposes its `tasks` array
    /// and the reorder rewrites `order` to match the post-sort positions.
    /// Drag-scoped so unrelated sections keep their `order` untouched.
    private func move(_ tasks: [TodoTask], from source: IndexSet, to destination: Int) {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        Repository.reorder(reordered, in: ctx)
    }

    // MARK: - Bucketing

    /// Open tasks whose due date is strictly before the start of today.
    /// Sorted earliest-due-first, then by manual `order`.
    private var overdue: [TodoTask] {
        openTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return due < startOfToday
            }
            .sorted { lhs, rhs in
                let l = lhs.dueDate ?? .distantFuture
                let r = rhs.dueDate ?? .distantFuture
                if l != r { return l < r }
                return lhs.order < rhs.order
            }
    }

    /// Open tasks due any time today. Sorted by priority (P1 first), then manual order.
    private var todays: [TodoTask] {
        openTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.order < rhs.order
            }
    }

    /// Tasks completed today (for the progress ring).
    private var doneToday: Int {
        completedTasks.filter { Calendar.current.isDateInToday($0.completedAt ?? .distantPast) }.count
    }

    // MARK: - Display buckets

    /// Sections to render for the current group mode. Each bucket's tasks
    /// are re-sorted with the user's chosen `sortMode` so the picker
    /// reshuffles the rows inside every section.
    private var displayedBuckets: [DisplayBucket] {
        let combined = overdue + todays
        switch groupMode {
        case .day:
            var buckets: [DisplayBucket] = []
            if !overdue.isEmpty {
                buckets.append(DisplayBucket(
                    id: "overdue",
                    label: "Overdue",
                    tasks: sortMode.apply(overdue),
                    icon: "exclamationmark.circle.fill",
                    tint: TK.accent
                ))
            }
            if !todays.isEmpty {
                // `label: nil` keeps the "Today" section header-less, matching
                // the original chrome exactly under the day group mode.
                buckets.append(DisplayBucket(
                    id: "today",
                    label: nil,
                    tasks: sortMode.apply(todays),
                    icon: nil,
                    tint: nil
                ))
            }
            return buckets

        case .priority:
            // P1 → P4 lanes; empty lanes are dropped so a section header
            // never appears without rows.
            return [1, 2, 3, 4].compactMap { p -> DisplayBucket? in
                let bucket = combined.filter { $0.priority == p }
                guard !bucket.isEmpty else { return nil }
                return DisplayBucket(
                    id: "p\(p)",
                    label: "P\(p)",
                    tasks: sortMode.apply(bucket),
                    icon: "circle.fill",
                    tint: TK.priority(p)
                )
            }

        case .project:
            // Un-sectioned first (named after the Inbox bucket), then one
            // section per project, sorted by project name for stable order.
            var buckets: [DisplayBucket] = []
            let unassigned = combined.filter { $0.project == nil }
            if !unassigned.isEmpty {
                buckets.append(DisplayBucket(
                    id: "no-project",
                    label: "No project",
                    tasks: sortMode.apply(unassigned),
                    icon: "tray",
                    tint: TK.secondary
                ))
            }
            let byProject = Dictionary(grouping: combined.filter { $0.project != nil }) { task in
                task.project?.id ?? UUID()
            }
            let projectIDs = byProject.keys.sorted { lhs, rhs in
                let l = byProject[lhs]?.first?.project?.name ?? ""
                let r = byProject[rhs]?.first?.project?.name ?? ""
                return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
            }
            for pid in projectIDs {
                let tasks = byProject[pid] ?? []
                guard let name = tasks.first?.project?.name else { continue }
                buckets.append(DisplayBucket(
                    id: "project-\(pid.uuidString)",
                    label: name,
                    tasks: sortMode.apply(tasks),
                    icon: "folder",
                    tint: nil
                ))
            }
            return buckets
        }
    }
}



// perf-probe
