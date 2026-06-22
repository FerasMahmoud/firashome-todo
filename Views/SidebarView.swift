import SwiftUI
import SwiftData

/// Top-level navigation sidebar shown inside `RootView`'s `NavigationSplitView`.
/// Tapping a row writes the chosen `NavDestination` back through the binding,
/// which drives the detail pane. Light theme only — relies on `TK.*` tokens.
struct SidebarView: View {
    @Binding var selection: NavDestination?

    /// SwiftData context — used by the drop-on-project gesture to reassign a
    /// dragged task to the dropped project.
    @Environment(\.modelContext) private var ctx

    /// All projects, sorted by manual `order`. Drives the "Projects" section rows.
    @Query(sort: \Project.order) private var projects: [Project]

    /// All open (uncompleted) tasks. Used to compute the counts shown on each row.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    var body: some View {
        // `List(selection:)` is the idiomatic NavigationSplitView sidebar pattern:
        // the list intercepts taps on rows that carry a `.tag(_)` and updates the
        // binding — no manual `selection = .x` plumbing needed in each row.
        List(selection: $selection) {
            // Smart views — no section header (matches Todoist sidebar).
            Section {
                smartRow(.search,
                         icon: "magnifyingglass",
                         label: "Search",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-search")
                smartRow(.inbox,
                         icon: "tray",
                         label: "Inbox",
                         tint: Color(hex: "246FE0"),
                         count: inboxCount,
                         id: "nav-inbox")
                smartRow(.today,
                         icon: "sun.max",
                         label: "Today",
                         tint: TK.accent,
                         count: todayCount,
                         id: "nav-today")
                smartRow(.upcoming,
                         icon: "calendar",
                         label: "Upcoming",
                         tint: TK.ink,
                         count: upcomingCount,
                         id: "nav-upcoming")
                smartRow(.calendar,
                         icon: "calendar.day.timeline.left",
                         label: "Calendar",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-calendar")
                smartRow(.activity,
                         icon: "list.bullet.rectangle.portrait",
                         label: "Activity",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-activity")
                smartRow(.productivity,
                         icon: "chart.bar.xaxis",
                         label: "Productivity",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-productivity")
                smartRow(.filters,
                         icon: "line.3.horizontal.decrease",
                         label: "Filters",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-filters")
                smartRow(.projects,
                         icon: "folder",
                         label: "Projects",
                         tint: TK.ink,
                         count: projects.count,
                         id: "nav-projects")
                smartRow(.account,
                         icon: "person.crop.circle",
                         label: "Account",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-account")
                smartRow(.settings,
                         icon: "gearshape",
                         label: "Settings",
                         tint: TK.ink,
                         count: nil,
                         id: "nav-settings")
            }

            // Per-project rows — labeled section, top-level projects first,
            // each followed by its indented sub-projects (recursive).
            Section("Projects") {
                ForEach(topLevelProjects) { project in
                    projectHierarchy(project, depth: 0)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Row builders

    /// A smart-view row: icon + label + optional trailing count.
    @ViewBuilder
    private func smartRow(_ dest: NavDestination,
                          icon: String,
                          label: String,
                          tint: Color,
                          count: Int?,
                          id: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .font(TK.body)
                .foregroundStyle(TK.ink)
            Spacer(minLength: 8)
            if let count, count > 0 {
                Text("\(count)")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(count) tasks")
            }
        }
        .contentShape(Rectangle())
        .tag(dest)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
    }

    /// Renders a project row plus its children recursively. Children are
    /// indented under the parent — each level adds a small left inset — but
    /// every row is still independently tappable and drops-accepting.
    /// Renders a project row plus its children recursively. Returns `AnyView`
    /// (type-erased) because a recursive `some View` opaque return would be
    /// "defined in terms of itself" and fail to compile.
    private func projectHierarchy(_ project: Project, depth: Int) -> AnyView {
        let sortedChildren = project.children.sorted { $0.order < $1.order }
        return AnyView(Group {
            projectRow(project, depth: depth)
            ForEach(sortedChildren) { child in
                projectHierarchy(child, depth: depth + 1)
            }
        })
    }

    /// A project row: leading color dot + name + trailing open-task count,
    /// with an optional indent spacer for sub-projects. Accepts a dropped
    /// task id (UUID string) and reassigns the task to this project.
    @ViewBuilder
    private func projectRow(_ project: Project, depth: Int) -> some View {
        HStack(spacing: 12) {
            if depth > 0 {
                // Indent guide for sub-projects. A transparent wedge keeps the
                // color dot, label, and count aligned with the parent's column.
                Color.clear
                    .frame(width: CGFloat(depth) * 14)
            }
            Circle()
                .fill(project.color)
                .frame(width: 12, height: 12)
            Text(project.name)
                .font(TK.body)
                .foregroundStyle(TK.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            let n = projectTaskCount(project)
            if n > 0 {
                Text("\(n)")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(n) open tasks")
            }
        }
        .contentShape(Rectangle())
        .tag(NavDestination.project(project.id))
        .accessibilityIdentifier("nav-project-\(project.id.uuidString)")
        .accessibilityLabel(project.name)
        .dropDestination(for: String.self) { ids, _ in
            // Mirrors `BoardView.move(taskID:to:)` — resolve the dragged id,
            // fetch the task, set its project, then save.
            guard let raw = ids.first, let uuid = UUID(uuidString: raw) else { return false }
            return moveTask(taskID: uuid, to: project)
        }
    }

    // MARK: - Counts

    /// Top-level projects only — sub-projects are rendered inline beneath
    /// their parent inside `projectHierarchy`.
    private var topLevelProjects: [Project] {
        projects.filter { $0.parent == nil }
    }

    /// Open tasks with no project — the Inbox bucket.
    private var inboxCount: Int {
        openTasks.reduce(into: 0) { acc, task in
            if task.project == nil { acc += 1 }
        }
    }

    /// Tasks due today OR earlier and still open.
    private var todayCount: Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        return openTasks.reduce(into: 0) { acc, task in
            guard let due = task.dueDate else { return }
            if due < startOfToday || cal.isDateInToday(due) { acc += 1 }
        }
    }

    /// Tasks due in the next 14 days (tomorrow through the horizon, exclusive of today).
    private var upcomingCount: Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        guard
            let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday),
            let horizon = cal.date(byAdding: .day, value: 14, to: startOfToday)
        else { return 0 }
        return openTasks.reduce(into: 0) { acc, task in
            guard let due = task.dueDate else { return }
            if due >= startOfTomorrow && due < horizon { acc += 1 }
        }
    }

    /// Open tasks assigned to this project.
    private func projectTaskCount(_ project: Project) -> Int {
        openTasks.reduce(into: 0) { acc, task in
            if task.project?.id == project.id { acc += 1 }
        }
    }

    // MARK: - Drag destination

    /// Resolve a dropped task by id and reassign it to `project`. Returns
    /// `false` when the id doesn't resolve or the task is already in this
    /// project (a no-op drop shouldn't claim a hit). The relation write +
    /// save go straight through the model context.
    @discardableResult
    private func moveTask(taskID: UUID, to project: Project) -> Bool {
        let id = taskID
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate<TodoTask> { $0.id == id }
        )
        guard let task = try? ctx.fetch(descriptor).first else { return false }
        guard task.project?.id != project.id else { return false }
        task.project = project
        do {
            try ctx.save()
            return true
        } catch {
            return false
        }
    }
}