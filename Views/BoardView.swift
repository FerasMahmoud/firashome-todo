import SwiftUI
import SwiftData

/// Kanban-style board for a single `Project`. Renders one column per
/// `TaskSection` (sorted by `order`) plus a trailing "No section" column for
/// tasks whose `section` is `nil`. Each column shows a header with the
/// section name + task count and a vertical lazy stack of task cards.
///
/// Cards are `.draggable(task.id.uuidString)`; columns are
/// `.dropDestination(for: String.self)`. Dropping a card moves the task into
/// the destination section via `Repository.setSection` — which writes the
/// relation, saves the context, and refreshes the widget snapshot. Dropping
/// onto the same section is a no-op.
///
/// The view is designed to fill the available height of its host (e.g. the
/// project detail body). The outer `ScrollView` claims the full vertical
/// extent via `.frame(maxHeight: .infinity)` and each column stretches to
/// match, so the inner `ScrollView` in the column body has a bounded height
/// and many cards scroll within the column instead of growing off-screen.
///
/// Light theme, `TK.*` tokens, no emojis, SF Symbols only. Per project
/// anchors all persistence routes through `Repository`.
struct BoardView: View {
    let project: Project

    @Environment(\.modelContext) private var ctx
    @Query private var allTasks: [TodoTask]

    /// Width of one board column. Picked to fit a 3-line title + due chip
    /// on the iPhone 17 Pro Max portrait width with comfortable padding.
    private let columnWidth: CGFloat = 280

    // MARK: - Derived state

    /// All open tasks in this project, in a stable display order: priority
    /// first (1 at the top, matching Todoist), then the user's manual
    /// `order`, then creation time as a tiebreaker. Mirrors
    /// `ProjectDetailView`'s sort so the board and the list stay consistent.
    private var projectTasks: [TodoTask] {
        allTasks
            .filter { $0.project?.id == project.id && !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// Sections in declared `order`. An empty `sections` collection is valid
    /// — the user just gets a single "No section" column.
    private var sortedSections: [TaskSection] {
        project.sections.sorted { $0.order < $1.order }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(sortedSections) { section in
                    column(for: section)
                }
                // Trailing bucket for un-sectioned tasks — always present so
                // dragging a card "below" the last defined section still
                // lands somewhere sensible.
                column(for: nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
        .background(TK.canvas)
        .accessibilityIdentifier("board-view")
    }

    // MARK: - Column

    @ViewBuilder
    private func column(for section: TaskSection?) -> some View {
        let tasks = tasksForSection(section)
        VStack(alignment: .leading, spacing: 10) {
            columnHeader(name: section?.name ?? "No section", count: tasks.count)
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    if tasks.isEmpty {
                        emptyColumnHint
                    } else {
                        ForEach(tasks) { task in
                            card(for: task)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(width: columnWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(12)
        .background(TK.grouped, in: RoundedRectangle(cornerRadius: TK.rCard))
        .dropDestination(for: String.self) { ids, _ in
            guard let raw = ids.first, let uuid = UUID(uuidString: raw) else { return false }
            return move(taskID: uuid, to: section)
        }
        .accessibilityIdentifier(columnID(for: section))
        .accessibilityLabel("\(section?.name ?? "No section"), \(tasks.count) tasks")
    }

    private func tasksForSection(_ section: TaskSection?) -> [TodoTask] {
        projectTasks.filter { $0.section?.id == section?.id }
    }

    private func columnID(for section: TaskSection?) -> String {
        if let id = section?.id {
            return "board-column-\(id.uuidString.prefix(8))"
        }
        return "board-column-none"
    }

    // MARK: - Header

    private func columnHeader(name: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(name.uppercased())
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
                .monospacedDigit()
        }
        .textCase(nil)
    }

    // MARK: - Card

    /// Visible card content (no drag / a11y wrappers). Extracted so `card(for:)`
    /// can reuse it for the drag preview WITHOUT recursing into itself (a
    /// recursive `some View` fails to compile).
    @ViewBuilder
    private func cardContent(for task: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 0) {
            UnevenRoundedRectangle(
                topLeadingRadius: TK.rCard,
                bottomLeadingRadius: TK.rCard,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(TK.priority(task.priority))
            .frame(width: 4)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let due = task.dueDate {
                    Text(dueChip(for: due))
                        .font(TK.subhead)
                        .foregroundStyle(TK.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    private func card(for task: TodoTask) -> some View {
        cardContent(for: task)
            .draggable(task.id.uuidString) {
                // Drag preview — a dimmed snapshot of the card, reusing the
                // extracted content (not a self-call).
                cardContent(for: task)
                    .opacity(0.85)
                    .frame(width: columnWidth - 24)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("board-card-\(task.id.uuidString.prefix(8))")
            .accessibilityLabel(cardAccessibilityLabel(for: task))
    }

    /// Short date string for the card's due line. Same shape as
    /// `TaskRowView`'s due chip: weekday for the next 7 days, otherwise
    /// day + abbreviated month. Keeps the board and the list visually
    /// consistent.
    private func dueChip(for due: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(due) { return "Today" }
        if cal.isDateInTomorrow(due) { return "Tomorrow" }
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: due)).day ?? 0
        if abs(days) <= 7 {
            return due.formatted(.dateTime.weekday(.abbreviated))
        }
        return due.formatted(.dateTime.day().month(.abbreviated))
    }

    private func cardAccessibilityLabel(for task: TodoTask) -> String {
        var parts: [String] = [task.title]
        if (1...3).contains(task.priority) {
            parts.append("priority \(task.priority)")
        }
        if let due = task.dueDate {
            parts.append("due \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Empty column hint

    private var emptyColumnHint: some View {
        Text("Drop tasks here")
            .font(TK.subhead)
            .foregroundStyle(TK.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
            .accessibilityHidden(true)
    }

    // MARK: - Move

    /// Resolve a dragged task by id and move it into `section`. Returns
    /// `false` to cancel the drop when the id doesn't resolve or the task
    /// is already in this section. Persistence + snapshot refresh go
    /// through `Repository.setSection`.
    @discardableResult
    private func move(taskID: UUID, to section: TaskSection?) -> Bool {
        let id = taskID
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate<TodoTask> { $0.id == id }
        )
        guard let task = try? ctx.fetch(descriptor).first else { return false }
        guard task.section?.id != section?.id else { return false }
        Repository.setSection(task, to: section, in: ctx)
        return true
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TodoTask.self, Project.self, Label.self, TaskSection.self,
        configurations: config
    )
    let ctx = container.mainContext

    let work = Project(name: "FITech", colorHex: "246FE0", order: 0, isFavorite: true)
    ctx.insert(work)

    let today = TaskSection(name: "Today", order: 0, project: work)
    let week = TaskSection(name: "This week", order: 1, project: work)
    let later = TaskSection(name: "Later", order: 2, project: work)
    ctx.insert(today)
    ctx.insert(week)
    ctx.insert(later)

    let now = Date()
    let cal = Calendar.current
    let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
    let nextWeek = cal.date(byAdding: .day, value: 5, to: now) ?? now
    let nextMonth = cal.date(byAdding: .day, value: 21, to: now) ?? now

    let cards: [TodoTask] = [
        TodoTask(title: "Review Q3 drone proposal with Firas",
                 dueDate: now, priority: 1, order: 0, project: work, section: today),
        TodoTask(title: "Pay supplier invoice",
                 dueDate: now, priority: 2, order: 1, project: work, section: today),
        TodoTask(title: "Send weekly status report",
                 dueDate: tomorrow, priority: 2, order: 2, project: work, section: week),
        TodoTask(title: "Schedule team retro",
                 priority: 3, order: 3, project: work, section: week),
        TodoTask(title: "Read SAM3 architecture paper",
                 dueDate: nextWeek, priority: 4, order: 4, project: work, section: later),
        TodoTask(title: "Plan offsite agenda",
                 dueDate: nextMonth, priority: 2, order: 5, project: work, section: later),
        TodoTask(title: "Triage open PRs",
                 priority: 3, order: 6, project: work, section: nil),
        TodoTask(title: "Archive old screenshots",
                 priority: 4, order: 7, project: work, section: nil)
    ]
    for t in cards { ctx.insert(t) }

    return BoardView(project: work)
        .modelContainer(container)
}
#endif
