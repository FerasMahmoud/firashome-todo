import SwiftUI
import SwiftData

/// Plain Todoist-style list of tasks. Used by Today, Upcoming, Filters, and Project detail.
/// Renders each task as a `TaskRowView`, optionally grouped under a section header.
///
/// Tier-2 #11 — bulk actions. Tap "Edit" in the toolbar to enter multi-select
/// mode; pick rows with the leading circles; the bottom bar exposes Complete,
/// Archive, and Delete applied to every selection. The selection lives in a
/// `Set<UUID>` bound to the `List`; the standard `\.editMode` environment
/// drives the rest. After a bulk action both the selection and edit mode
/// are cleared so the next entry starts in its default browse state.
///
/// Per _SPEC.md §TaskListView — public surface is `init(tasks:header:)` with an optional
/// `header`; callers decide whether the rows appear grouped under a section title or as a
/// flat list.
struct TaskListView: View {
    let tasks: [TodoTask]
    let header: String?

    @Environment(\.modelContext) private var ctx
    @Environment(\.editMode) private var editMode

    /// Multi-select state. Bound to the `List` so SwiftUI manages the
    /// leading circles and the checkmark glyphs automatically. Identified
    /// by `TodoTask.id` (UUID) so the set stays correct across reorders
    /// and row insertions.
    @State private var selection: Set<UUID> = []

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

    /// Tasks currently selected via the multi-select circles. Re-resolved
    /// against `tasks` (not just the selection set) so the actions can
    /// only ever touch rows owned by THIS list — a different `TaskListView`
    /// elsewhere in the hierarchy won't get its rows mutated by mistake
    /// when a UUID collides between two screens.
    private var selectedTasks: [TodoTask] {
        tasks.filter { selection.contains($0.id) }
    }

    /// Mark every selected task complete. If all selected are already
    /// completed, flip them back to incomplete instead — the smart variant
    /// matches iOS Reminders / Mail and avoids a "nothing happened" tap on
    /// a homogeneous-completed selection. Uses `Repository.setCompleted`
    /// (not `toggle`) so a mixed selection converges to one state, not a
    /// net wash.
    private func bulkComplete() {
        let selected = selectedTasks
        guard !selected.isEmpty else { return }
        let allCompleted = selected.allSatisfy(\.isCompleted)
        for task in selected {
            Repository.setCompleted(task, to: !allCompleted, in: ctx)
        }
        finishBulk()
    }

    /// Delete every selected task. `Repository.delete` cancels the pending
    /// notification and refreshes the widget snapshot in one shot per task.
    private func bulkDelete() {
        for task in selectedTasks {
            Repository.delete(task, in: ctx)
        }
        finishBulk()
    }

    /// Archive every selected task. Idempotent — already-archived tasks
    /// just bump `updatedAt`. The Archive screen is the only place the
    /// rows show up afterwards, mirroring single-row archive behaviour.
    private func bulkArchive() {
        for task in selectedTasks {
            Repository.archive(task, in: ctx)
        }
        finishBulk()
    }

    /// Clear the selection and exit edit mode so the next entry to the
    /// list starts in its default browse state. Called once per bulk
    /// action — never leaves the user stranded in edit mode with no
    /// visible affordance.
    private func finishBulk() {
        selection.removeAll()
        editMode?.wrappedValue = .inactive
    }

    var body: some View {
        List(selection: $selection) {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .accessibilityIdentifier("task-list-edit-button")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if editMode?.wrappedValue == .active && !selection.isEmpty {
                bulkActionBar
            }
        }
    }

    /// Shared row rendering so the two list shapes (with/without section header) apply
    /// identical swipe actions and styling — single source of truth for row chrome.
    @ViewBuilder
    private var rows: some View {
        ForEach(tasks, id: \.id) { task in
            TaskRowView(task: task)
                // Tag the row with its UUID so the List's selection set
                // (Set<UUID>) can address it. Without this, SwiftUI's
                // selection binding has nothing to match against.
                .tag(task.id)
                .listRowBackground(TK.canvas)
                .listRowSeparatorTint(TK.hairlineSoft)
                // swipe + context-menu actions live on TaskRowView now.
        }
        .onMove(perform: move)
    }

    /// Bottom action bar — only mounted during active edit mode with at
    /// least one row selected. `safeAreaInset` keeps it above the home
    /// indicator and pushes list content up so the last row never hides
    /// beneath it. iOS-native three-button pattern: Complete, Archive,
    /// Delete (destructive on the right, matching Mail / Notes).
    private var bulkActionBar: some View {
        HStack(spacing: 0) {
            bulkButton(
                "Complete",
                systemImage: "checkmark.circle.fill",
                tint: Color(red: 0.18, green: 0.69, blue: 0.34),
                action: bulkComplete
            )
            bulkButton(
                "Archive",
                systemImage: "archivebox.fill",
                tint: TK.ink,
                action: bulkArchive
            )
            bulkButton(
                "Delete",
                systemImage: "trash",
                tint: TK.accent,
                action: bulkDelete
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(TK.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(TK.hairline)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-list-bulk-bar")
    }

    /// One cell of `bulkActionBar`. Vertical icon-over-label is the
    /// standard iOS edit-bar shape. `.buttonStyle(.plain)` so each tap
    /// target fills its grid cell — no rounded-rect "button" look that
    /// would clash with the minimalist list chrome above.
    private func bulkButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("task-list-bulk-\(title.lowercased())")
    }
}
