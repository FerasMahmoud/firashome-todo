import SwiftUI
import SwiftData

/// Plain Todoist-style list of tasks. Used by Today, Upcoming, Filters, and Project detail.
/// Renders each task as a `TaskRowView`, optionally grouped under a section header.
///
/// Per _SPEC.md §TaskListView — public surface is `init(tasks:header:)` with an optional
/// `header`; callers decide whether the rows appear grouped under a section title or as a
/// flat list.
struct TaskListView: View {
    @Environment(\.modelContext) private var context

    let tasks: [TodoTask]
    let header: String?

    init(tasks: [TodoTask], header: String? = nil) {
        self.tasks = tasks
        self.header = header
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
            .listRowBackground { if TK.isDarkGlass { Rectangle().fill(.thinMaterial) } else { TK.canvas } }
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Repository.delete(task, in: context)
                    } label: {
                        HStack { Image(systemName: "trash"); Text("Delete") }
                    }
                    .tint(TK.accent)
                    .accessibilityIdentifier("task-row-delete")
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Repository.toggle(task, in: context)
                    } label: {
                        HStack {
                            Image(systemName: task.isCompleted
                                ? "arrow.uturn.backward.circle"
                                : "checkmark.circle.fill")
                            Text(task.isCompleted ? "Undo" : "Complete")
                        }
                    }
                    // Todoist-complete green — kept inline so we don't widen the global TK palette.
                    .tint(Color(red: 0.18, green: 0.69, blue: 0.34))
                    .accessibilityIdentifier("task-row-complete")
                }
        }
    }
}

