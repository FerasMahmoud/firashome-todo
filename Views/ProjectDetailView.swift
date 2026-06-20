import SwiftUI
import SwiftData

/// Project detail screen — every task that belongs to a single project.
///
/// Mirrors Todoist's project view: project color dot in the title, an "Active"
/// section listing open tasks grouped under the project, and a collapsible
/// "X completed" section for finished work. Shows a centered empty state when
/// the project has no tasks at all. Light theme only — relies on `TK.*` tokens.
///
/// Constructed with the project UUID (not a `Project` directly) because the
/// detail pane receives only the ID through `NavDestination.project(_:)`.
struct ProjectDetailView: View {
    /// Identifier of the project to display. Resolved against the SwiftData
    /// store on every render via `@Query`.
    let projectID: UUID

    @Environment(\.modelContext) private var context
    @Query(sort: \Project.order) private var allProjects: [Project]
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    /// Disclosure state for the "X completed" section.
    @State private var showCompleted = false

    // MARK: - Derived state

    /// The project this screen is showing, if it still exists in the store.
    private var project: Project? {
        allProjects.first { $0.id == projectID }
    }

    /// Every task belonging to this project (open or completed).
    private var projectTasks: [TodoTask] {
        allTasks.filter { $0.project?.id == projectID }
    }

    /// Open tasks — Todoist orders by priority first (p1 at the top), then by
    /// the user's manual `order` so the sequence inside a priority tier is
    /// stable across reloads.
    private var incompleteTasks: [TodoTask] {
        projectTasks
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// Completed tasks — most recently completed first, matching Todoist.
    private var completedTasks: [TodoTask] {
        projectTasks
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let project {
                content(for: project)
            } else {
                missingProject
            }
        }
        .background(TK.canvas)
        .navigationTitle(project?.name ?? "Project")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let project {
                // In compact (scrolled) mode the principal slot replaces the
                // large title with an inline one — show the colored dot here
                // so the project's identity stays visible while the list scrolls.
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(TK.ink)
                            .lineLimit(1)
                    }
                    .accessibilityIdentifier("project-title")
                    .accessibilityLabel("Project \(project.name)")
                }
            }
        }
    }

    // MARK: - Content routing

    @ViewBuilder
    private func content(for project: Project) -> some View {
        if projectTasks.isEmpty {
            emptyState(for: project)
        } else {
            taskList(for: project)
        }
    }

    // MARK: - Empty state

    private func emptyState(for project: Project) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("No tasks yet")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Tap + to add a task to \(project.name)")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("project-empty-state")
        .accessibilityLabel("No tasks yet. Tap + to add a task to \(project.name).")
    }

    // MARK: - Task list

    private func taskList(for project: Project) -> some View {
        List {
            Section {
                if incompleteTasks.isEmpty {
                    // Project has tasks but none are open — show a soft
                    // "all caught up" line so the section header still
                    // anchors the screen to the project.
                    Text("All caught up")
                        .font(TK.subhead)
                        .foregroundStyle(TK.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(TK.canvas)
                        .accessibilityIdentifier("project-all-caught-up")
                } else {
                    ForEach(incompleteTasks) { task in
                        rowLink(for: task)
                    }
                }
            } header: {
                activeHeader(for: project)
            }

            if !completedTasks.isEmpty {
                Section {
                    if showCompleted {
                        ForEach(completedTasks) { task in
                            rowLink(for: task)
                        }
                    }
                } header: {
                    completedHeader
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(TK.canvas)
    }

    // MARK: - Row

    /// A row wrapped in a `NavigationLink` to the task editor, plus leading
    /// "Complete / Undo" and trailing "Delete" swipe actions — matches the
    /// gestures Todoist exposes on every list row.
    @ViewBuilder
    private func rowLink(for task: TodoTask) -> some View {
        NavigationLink {
            TaskDetailView(task: task)
        } label: {
            TaskRowView(task: task)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Repository.delete(task, in: context)
            } label: {
                HStack { Image(systemName: "trash"); Text("Delete") }
            }
            .accessibilityIdentifier("project-swipe-delete-\(task.id.uuidString.prefix(8))")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Repository.toggle(task, in: context)
            } label: {
                HStack {
                    Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    Text(task.isCompleted ? "Undo" : "Complete")
                }
            }
            .tint(.green)
            .accessibilityIdentifier("project-swipe-complete-\(task.id.uuidString.prefix(8))")
        }
        .accessibilityIdentifier("project-row-\(task.id.uuidString.prefix(8))")
    }

    // MARK: - Section headers

    /// Active section header — project color dot, name, and open-task count.
    private func activeHeader(for project: Project) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(project.color)
                .frame(width: 10, height: 10)
            Text(project.name.uppercased())
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
            Spacer(minLength: 0)
            if !incompleteTasks.isEmpty {
                Text("\(incompleteTasks.count)")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                    .monospacedDigit()
            }
        }
        .textCase(nil)
        .accessibilityIdentifier("project-section-active")
        .accessibilityLabel("\(project.name), \(incompleteTasks.count) open tasks")
    }

    /// Collapsible "X completed" header — tap toggles the disclosure. Todoist
    /// uses the same chevron + count pattern, hidden until the user expands.
    private var completedHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showCompleted.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TK.secondary)
                Text("\(completedTasks.count) COMPLETED")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .textCase(nil)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("project-completed-toggle")
        .accessibilityLabel("\(completedTasks.count) completed tasks")
        .accessibilityValue(showCompleted ? "expanded" : "collapsed")
        .accessibilityHint(showCompleted ? "Tap to collapse" : "Tap to expand")
    }

    // MARK: - Missing project

    private var missingProject: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("Project not found")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("It may have been deleted.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("project-missing")
    }

    // MARK: - Preview seed

    /// Builds an in-memory container preloaded with a single project that has
    /// a mix of active and completed tasks. Used only by the `#Preview` block
    /// below so the canvas renders the populated state instead of the empty
    /// placeholder.
    static func previewContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TodoTask.self, Project.self, Label.self,
            configurations: config
        )
        let ctx = container.mainContext

        let work = Project(name: "FITech", colorHex: "246FE0", order: 0, isFavorite: true)
        let home = Project(name: "Personal", colorHex: "E03982", order: 1)
        ctx.insert(work)
        ctx.insert(home)

        let now = Date()
        let cal = Calendar.current

        let active: [TodoTask] = [
            TodoTask(
                title: "Review Q3 drone proposal with Firas",
                priority: 1, order: 0, project: work,
                dueDate: now
            ),
            TodoTask(
                title: "Send weekly status report",
                priority: 2, order: 1, project: work,
                dueDate: cal.date(byAdding: .day, value: 1, to: now)
            ),
            TodoTask(
                title: "Pick up groceries on the way home",
                priority: 3, order: 2, project: home,
                dueDate: cal.date(byAdding: .day, value: 1, to: now)
            ),
            TodoTask(
                title: "Read SAM3 architecture paper",
                priority: 4, order: 3, project: work
            )
        ]

        let done: [TodoTask] = [
            TodoTask(
                title: "Walk the dog before it gets dark",
                priority: 1, order: 4, project: home,
                dueDate: cal.date(byAdding: .day, value: -1, to: now)
            ),
            TodoTask(
                title: "Archive old screenshots",
                priority: 4, order: 5, project: work
            )
        ]

        for t in active { ctx.insert(t) }
        for t in done {
            ctx.insert(t)
            t.completedAt = now
        }

        return container
    }
}

// MARK: - Preview






