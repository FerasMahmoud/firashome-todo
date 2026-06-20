# Views spec — Todoist-clone, light theme

GOAL: make a user feel EXACTLY like they're using real Todoist. Match layout, spacing, type, interactions, micro-copy, empty states. Premium + restrained (no emoji, SF Symbols only, one red accent).

## Hard rules (every file)
- `import SwiftUI` and `import SwiftData` at top.
- Target iOS 17 (SwiftData). Use `if #available(iOS 26, *)` for any `.glassEffect()`/Liquid Glass — wrap optional.
- Light theme: backgrounds `TK.canvas` / `TK.grouped`; text `TK.ink` / `TK.secondary`; hairlines `TK.hairline`. Single accent `TK.accent`.
- Fonts via `TK.title/.headline/.body/.subhead/.sectionHeader`.
- Round corners `TK.rRow` (rows) / `TK.rCard` (cards) / `TK.rPill`.
- Read data with `@Query` and `@Environment(\.modelContext)`. Mutate via `Repository.*` then `try? context.save()` or direct property set + save.
- NO emojis. NO third-party deps. NO UIKit unless unavoidable.
- Every interactive control gets an `.accessibilityIdentifier`.
- Provide a `#Preview` using an in-memory container:
  `#Preview { <View>().modelContainer(for: [TodoTask.self, Project.self, Label.self], inMemory: true) }`

## Model API (do not change — these are defined in Models/)
- `TodoTask`: `id, title, note, createdAt, dueDate: Date?, completedAt: Date?, priority: Int (1..4), order, project: Project?, labels: [Label]`, computed `isCompleted: Bool`.
- `Project`: `id, name, colorHex, order, isFavorite, tasks: [TodoTask]`, `color: Color`.
- `Label`: `id, name, colorHex, tasks: [TodoTask]`, `color: Color`.

## Tokens (Design/Tokens.swift)
`TK.canvas .grouped .card .ink .secondary .hairline .hairlineSoft .accent`, `TK.priority(int)`, `TK.rRow .rCard .rPill`, `TK.title .headline .body .subhead .sectionHeader`. `Color(hex:)`.

## Per-view contracts

### SidebarView.swift
`struct SidebarView: View` with `@Binding var selection: NavDestination?`.
- `List { Section { rows } }` with `.listStyle(.sidebar)`.
- Top rows (NavigationLink-like Buttons that set selection): Today → `.today` (icon "calendar", accent), Upcoming → `.upcoming` ("calcalendar" use "tray.full" for Today? USE: Today="sun.max", Upcoming="calendar", Filters="line.3.horizontal.decrease"). accessibilityIdentifier: "nav-today", "nav-upcoming", "nav-filters".
- Section "Projects" header; rows from `@Query(sort:\.order) var projects`. Each Button sets `selection = .project(project.id)`, leading dot `Circle().fill(project.color)`, trailing task count. id "nav-projects" goes on the SECTION itself is not tappable — instead add a "Projects" summary row? SIMPLER: add a top row "Projects" → `.projects` with id "nav-projects" (icon "folder").
- Section "Labels" preview (optional, first 5) not required; skip to keep clean.
- Highlight the row whose selection matches (use `.tint`/background).
- Title: big "Tasks" wordmark at top in a header area.

### TaskRowView.swift
`struct TaskRowView: View` with `let task: TodoTask` and `@Environment(\.modelContext)`.
- HStack: leading checkbox = `Button { Repository.toggle(task, in: ctx) } label: { Circle().strokeBorder(TK.priority(task.priority), lineWidth: 1.8).frame(18) }`. On complete, checkbox fills accent + checkmark; title strikes through + fades to secondary.
- Middle VStack(alignment:.leading): title (TK.body, lineLimit 2), bottom row: project color dot + project name (secondary, 13), due chip "Today/Tomorrow/Mon" (secondary, with clock icon if overdue → accent).
- Trailing: priority flag icon for p1/p2/p3 ("flag.fill" colored TK.priority). p4 nothing.
- Row inset grouped style, tap opens detail (NavigationLink in parent). `.contentShape(Rectangle())`.

### TaskListView.swift
`struct TaskListView: View` with `let tasks: [TodoTask]` and optional `let header: String?`.
- `List { if let header { Section(header) { ForEach(tasks) { TaskRowView(task: $0) } } } else { ForEach(tasks) { TaskRowView(task: $0) } } }`. `.listStyle(.plain)`, `.scrollContentBackground(.hidden)`, `.background(TK.canvas)`.
- `.swipeActions` on rows: trailing red "Delete" → `Repository.delete`; leading "Complete" green.

### TodayView.swift
`struct TodayView: View`.
- `@Query(filter:, sort:)` for tasks due today or overdue & not completed. Use a predicate: dueDate < tomorrow-start AND completedAt == nil. (If predicate macro is awkward, fetch all incomplete and filter in Swift by Calendar.isDateInToday/isOverdue.)
- `NavigationStack`/content with title area: large title "Today" + subtitle today's date (e.g. "Thu 20 Jun"). Use `.navigationTitle("Today")` `.navigationBarTitleDisplayMode(.large)`.
- Group into sections: "Overdue" (red-tinted) then "Today". Use `TaskListView`.
- If empty: centered empty state — icon "checkmark.circle" tinted secondary, "You're all clear for today", subtext "Tap + to add a task".
- leading inset so content clears Dynamic Island / status bar naturally (system handles).

### UpcomingView.swift
`struct UpcomingView: View`. Title "Upcoming" + date subtitle. `@Query` incomplete tasks with dueDate in next 14 days. Group by day: Section per day ("Tomorrow", "Fri 21 Jun", etc.). Each section → `TaskListView(tasks:, header:nil)` inside `Section(dayLabel)`. Empty state: "Nothing on the horizon".

### FiltersView.swift
`struct FiltersView: View`. Title "Filters". `List` of built-in filter rows (icon + name + count badge): "Priority 1" (flag.fill red), "Overdue", "Today", "Next 7 days", "No date". Counts computed from `@Query`. Rows styled like Todoist filter rows (tappable, secondary chevrons optional). This view is a static catalog of filters (no query editor for v1).

### ProjectsView.swift
`struct ProjectsView: View`. Title "Projects". `@Query(sort:\.order) var projects`. List rows: colored circle + name + task count, tap → sets nothing (in sidebar context) but here render as `NavigationLink`? NO — keep as plain list with chevrons; selection handled by parent in sidebar. Provide an "Add project" button in toolbar (system "plus") that shows an alert/sheet to name a project + pick color (simple TextField alert is fine).

### LabelsView.swift
`struct LabelsView: View`. Title "Labels". `@Query var labels`. Rows: "#" prefix + colored dot + name + count. Simple, Todoist-label style.

### ProjectDetailView.swift
`struct ProjectDetailView: View` with `let projectID: UUID`. Fetch the project (`@Query` all projects, `.first { $0.id == projectID }`). Title = project.name with its color dot. Show incomplete tasks grouped, then completed section (collapsed "X completed"). Empty state: "No tasks yet". `.navigationTitle(project.name)`.

### TaskDetailView.swift
`struct TaskDetailView: View` with `let task: TodoTask`. Edit form: title TextField, note TextEditor, project Picker, due date DatePicker (.compact), priority Picker (1..4). Save on change. Delete button at bottom (red). `.navigationTitle("Task")`.

### QuickAddView.swift
`struct QuickAddView: View` with `@Environment(\.dismiss)`. Presented as bottom sheet (`.presentationDetents([.medium, .large])`). VStack: large TextField "e.g., Review drone brief @urgent #FITech" (natural-input placeholder). Row of quick controls: project picker (menu), date picker (menu: Today/Tomorrow/Next week/No date), priority (menu p1-p4). Bottom: "Cancel" (secondary) + "Add task" (accent filled button, disabled if title empty). On Add: `Repository.add(title, project:, due:, priority:)` then dismiss. Match Todoist quick-add sheet look: clean, rounded, subtle shadow.

## Completion order
Implement SidebarView + TaskRowView + TaskListView first (others depend on them), then the screens. But since each agent owns one file, just satisfy the contract exactly — do not invent new public symbols.
