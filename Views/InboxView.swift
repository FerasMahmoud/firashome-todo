import SwiftUI
import SwiftData

/// "Inbox" screen — every open task with no project assigned. Mirrors Todoist's
/// Inbox: the catch-all bucket that sits at the top of the sidebar.
struct InboxView: View {
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil && $0.project == nil })
    private var openTasks: [TodoTask]

    @Environment(\.modelContext) private var ctx

    /// Persisted sort order. Lives in AppStorage so the choice survives
    /// across launches and is per-view (this key is Inbox-only).
    @AppStorage("inbox-sort-mode") private var sortMode: SortMode = .priorityOrder

    /// Display-only sort. Each case wraps one of the `TaskSort` helpers so
    /// the screen reads consistently with the rest of the app for the same
    /// intent. The toolbar Picker drives this — `apply(_:)` re-sorts the
    /// displayed tasks.
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

    /// Drag-to-reorder within the inbox bucket. Renumbers all inbox tasks so
    /// the new sequence persists across the next @Query refresh.
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = sortedTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        Repository.reorder(reordered, in: ctx)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom large title — extra leading space (28pt vs iOS default 16pt).
            HStack(spacing: 0) {
                Text("Inbox")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(TK.ink)
                Spacer(minLength: 0)
            }
            .padding(.leading, 28)
            .padding(.trailing, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            content
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
    }

    /// Toolbar sort menu. The icon bounces on each selection so the user
    /// gets a visible acknowledgement that the choice was registered.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    SwiftUI.Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .symbolEffect(.bounce, value: sortMode)
        }
        .accessibilityLabel("Sort order")
        .accessibilityIdentifier("inbox-sort-menu")
    }

    @ViewBuilder
    private var content: some View {
        if openTasks.isEmpty {
            emptyState
        } else {
            List {
                Section {
                    ForEach(sortedTasks) { task in
                        TaskRowView(task: task)
                        .listRowSeparatorTint(TK.hairlineSoft)
                    }
                    .onMove(perform: move)
                } header: {
                    Text("Tasks")
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)

            .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
            // Spring animation bound to the row count — covers @Query
            // refreshes (a task added to or removed from the inbox from
            // elsewhere in the app) so rows glide in / out instead of
            // snapping. The sort picker doesn't change the count, but
            // the safety net is free.
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sortedTasks.count)
        }
    }

    private var sortedTasks: [TodoTask] {
        sortMode.apply(openTasks)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
            Text("Inbox zero")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Tasks you add without a project land here.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .accessibilityIdentifier("inbox-empty-state")
    }
}
