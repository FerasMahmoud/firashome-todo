import SwiftUI
import SwiftData

/// "Upcoming" screen — incomplete tasks due in the next 14 days, grouped per day.
/// Mirrors real Todoist: a per-day list with "Tomorrow" / "Mon 21 Jun" section headers,
/// a centred empty state when nothing is scheduled, and no chrome beyond the system nav title.
///
/// Toolbar exposes a Sort picker (re-orders rows inside every section) and a
/// Group picker (day / flat / project). Both persist in AppStorage.
struct UpcomingView: View {
    // Incomplete tasks only. SwiftData sorts the optional `dueDate` keypath with nils last.
    @Query(
        filter: #Predicate<TodoTask> { task in
            task.completedAt == nil
        },
        sort: \.dueDate
    )
    private var incomplete: [TodoTask]

    @Environment(\.modelContext) private var ctx
    @State private var selectedDay: Date?

    /// Persisted sort order. Per-view key.
    @AppStorage("upcoming-sort-mode") private var sortMode: SortMode = .priorityOrder

    /// Persisted grouping mode. Per-view key.
    @AppStorage("upcoming-group-mode") private var groupMode: GroupMode = .day

    /// Display-only sort. Each case wraps one of the `TaskSort` helpers —
    /// the toolbar Picker drives this; `apply(_:)` re-sorts the displayed
    /// tasks inside every section.
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

    /// Section shape. `day` is the original per-day split (the default);
    /// `flat` collapses to a single section-less list; `project` buckets
    /// by project. All three honour the selected sort inside each section.
    private enum GroupMode: String, CaseIterable, Identifiable {
        case day
        case flat
        case project

        var id: String { rawValue }

        var label: String {
            switch self {
            case .day: return "Day"
            case .flat: return "Flat"
            case .project: return "Project"
            }
        }

        var systemImage: String {
            switch self {
            case .day: return "calendar"
            case .flat: return "list.bullet"
            case .project: return "folder"
            }
        }
    }

    /// One renderable section. `id` is stable across re-renders so the
    /// ForEach diff can identify which sections appear / disappear as the
    /// group mode changes — that's what makes the section transition fire.
    /// `label == nil` renders a section with no header (used by the flat
    /// group mode where the top-of-list subtitle already names the day).
    private struct DisplayBucket: Identifiable {
        let id: String
        let label: String?
        let tasks: [TodoTask]
        let icon: String?
        let tint: Color?
    }

    private let horizonDays = 14

    var body: some View {
        ZStack {
            TK.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                dateStrip
                if displayedBuckets.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationTitle("Upcoming")
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

    /// Sort picker. Icon bounces on each change so the user gets visible
    /// acknowledgement even when the new order looks the same.
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
        .accessibilityIdentifier("upcoming-sort-menu")
    }

    /// Group picker. Icon bounces on each change so the section re-shuffle
    /// is signalled in the toolbar even before the list re-renders.
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
        .accessibilityIdentifier("upcoming-group-menu")
    }

    // MARK: - Date strip

    private var dateStrip: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stripDays, id: \.self) { day in
                        DatePill(
                            day: day,
                            isToday: Calendar.current.isDateInToday(day),
                            isSelected: isSelected(day),
                            onTap: { toggle(day) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            Rectangle()
                .fill(TK.hairline)
                .frame(height: 0.5)
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .accessibilityIdentifier("upcoming-date-strip")
    }

    /// 14 days starting from today — the strip window. Mirrors `horizonDays`.
    /// `buckets` uses `horizonStart = tomorrow` because TodayView owns today's tasks;
    /// the strip still includes today so the user can drill into it.
    private var stripDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<horizonDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
        }
    }

    private func isSelected(_ day: Date) -> Bool {
        guard let selected = selectedDay else { return false }
        return Calendar.current.isDate(selected, inSameDayAs: day)
    }

    /// Tap-to-select with tap-to-deselect on the active pill — keeps one-tap escape hatch.
    private func toggle(_ day: Date) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: day)
        if let selected = selectedDay, cal.isDate(selected, inSameDayAs: startOfDay) {
            selectedDay = nil
        } else {
            selectedDay = startOfDay
        }
    }

    // MARK: - Sections

    private var list: some View {
        List {
            // Subtitle header — sits at the very top of the list, just below the large title.
            Section {
                EmptyView()
            } header: {
                Text(subtitle)
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .textCase(nil)
                    .accessibilityIdentifier("upcoming-subtitle")
            }

            ForEach(displayedBuckets) { bucket in
                Section {
                    // Rows inlined (NOT a nested List) so day headers + rows share one grid.
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
                        .accessibilityIdentifier("upcoming-bucket-header-\(bucket.id)")
                    }
                }
                // Section-level transition: when group mode changes and a
                // section appears or disappears, glide it in from the top
                // with an opacity fade.
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)

        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)

        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        // Spring animation bound to the bucket count — covers task add /
        // remove from the underlying @Query. The .animation(value:)
        // modifier also propagates to the section transitions on
        // group-mode change because the section count is part of the
        // bucket structure.
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sortMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: groupMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: displayedBuckets.count)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityIdentifier("upcoming-empty-icon")
            Text("Nothing on the horizon")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
                .accessibilityIdentifier("upcoming-empty-title")
            Text("Tasks with due dates in the next 14 days will appear here.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("upcoming-empty-subtitle")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
    }

    // MARK: - Derived

    /// "Fri 20 Jun" — matches the TodayView subtitle style.
    private var subtitle: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Start of tomorrow — TodayView already owns today's tasks, so Upcoming starts tomorrow.
    private var horizonStart: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return cal.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// End of the 14th day out, exclusive upper bound for the date filter.
    private var horizonEnd: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return cal.date(byAdding: .day, value: horizonDays, to: today) ?? today
    }

    /// Tasks in the horizon window — pre-filtered once so every group
    /// mode reads from the same source. Date scoping is independent of
    /// the chosen group mode.
    private var inWindow: [TodoTask] {
        let start = horizonStart
        let end = horizonEnd
        return incomplete.compactMap { task -> TodoTask? in
            guard let due = task.dueDate, due >= start, due < end else { return nil }
            return task
        }
    }

    /// Tasks scoped to the selected day, or the full horizon when no day
    /// is selected. Mirrors the original `filteredBuckets` fallback — if
    /// the selected day has no tasks, the full upcoming list shows so the
    /// user is never stuck on an empty body.
    private var scopedTasks: [TodoTask] {
        guard let day = selectedDay else { return inWindow }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: day)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let onDay = incomplete.compactMap { task -> TodoTask? in
            guard let due = task.dueDate, due >= startOfDay, due < endOfDay else { return nil }
            return task
        }
        guard !onDay.isEmpty else { return inWindow }
        return onDay
    }

    /// Sections to render for the current group mode. Each bucket's tasks
    /// are re-sorted with the user's chosen `sortMode` so the picker
    /// reshuffles the rows inside every section.
    private var displayedBuckets: [DisplayBucket] {
        let tasks = scopedTasks
        switch groupMode {
        case .day:
            // One bucket per day in the scoped window, sorted ascending.
            let cal = Calendar.current
            let grouped = Dictionary(grouping: tasks) { task in
                cal.startOfDay(for: task.dueDate ?? .now)
            }
            return grouped.keys.sorted().map { day in
                DisplayBucket(
                    id: "day-\(ISO8601DateFormatter().string(from: day))",
                    label: Self.label(for: day),
                    tasks: sortMode.apply(grouped[day] ?? []),
                    icon: nil,
                    tint: nil
                )
            }

        case .flat:
            // A single header-less bucket. The top-of-list "Upcoming"
            // subtitle already names the scope, so no per-section header.
            return [
                DisplayBucket(
                    id: "flat",
                    label: nil,
                    tasks: sortMode.apply(tasks),
                    icon: nil,
                    tint: nil
                )
            ]

        case .project:
            // Un-assigned tasks first, then one section per project,
            // sorted by project name for stable order.
            var buckets: [DisplayBucket] = []
            let unassigned = tasks.filter { $0.project == nil }
            if !unassigned.isEmpty {
                buckets.append(DisplayBucket(
                    id: "no-project",
                    label: "No project",
                    tasks: sortMode.apply(unassigned),
                    icon: "tray",
                    tint: TK.secondary
                ))
            }
            let byProject = Dictionary(grouping: tasks.filter { $0.project != nil }) { task in
                task.project?.id ?? UUID()
            }
            let projectIDs = byProject.keys.sorted { lhs, rhs in
                let l = byProject[lhs]?.first?.project?.name ?? ""
                let r = byProject[rhs]?.first?.project?.name ?? ""
                return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
            }
            for pid in projectIDs {
                let bucketTasks = byProject[pid] ?? []
                guard let name = bucketTasks.first?.project?.name else { continue }
                buckets.append(DisplayBucket(
                    id: "project-\(pid.uuidString)",
                    label: name,
                    tasks: sortMode.apply(bucketTasks),
                    icon: "folder",
                    tint: nil
                ))
            }
            return buckets
        }
    }

    private static func label(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: - Reorder

    /// Drag-to-reorder within a single bucket. Unified across all group
    /// modes (day, flat, project) — each section exposes its `tasks`
    /// array and the reorder rewrites `order` to match the post-sort
    /// positions. Cross-day moves would require rewriting the due date,
    /// so we scope each section's reorder to its own bucket.
    private func move(_ tasks: [TodoTask], from source: IndexSet, to destination: Int) {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        Repository.reorder(reordered, in: ctx)
    }
}

// MARK: - Date pill

/// One cell in the horizontal upcoming date strip.
/// Visuals: today always fills with `TK.accent`; selected non-today fills with `TK.ink`;
/// unselected sits on `TK.card` with a hairline border.
private struct DatePill: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(weekday)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                Text(dayNumber)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(textColor)
            .frame(width: 52, height: 64)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: TK.rPill, style: .continuous))
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: TK.rPill, style: .continuous)
                        .strokeBorder(TK.hairline, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: TK.rPill, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("upcoming-date-pill-\(dayNumber)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // Spring the colour flip when the pill is selected / deselected so
        // the tap feedback matches the spring on the rest of the screen.
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }

    private var weekday: String {
        day.formatted(.dateTime.weekday(.abbreviated))
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day))
    }

    private var textColor: Color {
        isToday || isSelected ? TK.canvas : TK.ink
    }

    private var backgroundColor: Color {
        if isToday { return TK.accent }
        if isSelected { return TK.ink }
        return TK.card
    }

    private var showBorder: Bool {
        !isToday && !isSelected
    }

    private var accessibilityLabel: String {
        let dateText = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if isToday { return "Today, \(dateText)" }
        if isSelected { return "Selected, \(dateText)" }
        return dateText
    }
}
