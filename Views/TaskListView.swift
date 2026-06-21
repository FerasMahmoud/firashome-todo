import SwiftUI
import SwiftData

/// Plain Todoist-style list of tasks. Used by Today, Upcoming, Filters, and Project detail.
/// Renders each task as a `TaskRowView`, optionally grouped under a section header.
///
/// Per _SPEC.md §TaskListView — public surface is `init(tasks:header:)` with an optional
/// `header`; callers decide whether the rows appear grouped under a section title or as a
/// flat list.
struct TaskListView: View {
    let tasks: [TodoTask]
    let header: String?

    @Environment(\.modelContext) private var ctx

    init(tasks: [TodoTask], header: String? = nil) {
        self.tasks = tasks
        self.header = header
    }

    /// Reorder within this list. Scoped to `tasks` so callers using
    /// `TaskListView` (Filters, label screen, etc.) get drag-to-reorder for
    /// free. iOS 16+: long-press-and-drag without entering edit mode.
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        Repository.reorder(reordered, in: ctx)
    }

    var body: some View {
        List {
            if let header {
                Section {
                    rows
                } header: {
                    Text(header)
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                        .textCase(nil)
                        .accessibilityIdentifier("task-list-header")
                }
            } else {
                rows
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)
            
        .background(TK.canvas)
    }

    /// Shared row rendering so the two list shapes (with/without section header) apply
    /// identical swipe actions and styling — single source of truth for row chrome.
    @ViewBuilder
    private var rows: some View {
        ForEach(tasks, id: \.id) { task in
            TaskRowView(task: task)
                .listRowBackground(TK.canvas)
                .listRowSeparatorTint(TK.hairlineSoft)
                // swipe + context-menu actions live on TaskRowView now.
        }
        .onMove(perform: move)
    }
}

