import SwiftUI
import SwiftData

/// "Inbox" screen — every open task with no project assigned. Mirrors Todoist's
/// Inbox: the catch-all bucket that sits at the top of the sidebar.
struct InboxView: View {
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil && $0.project == nil })
    private var openTasks: [TodoTask]

    @Environment(\.modelContext) private var ctx

    /// Drag-to-reorder within the inbox bucket. Renumbers all inbox tasks so
    /// the new sequence persists across the next @Query refresh.
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = sorted
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
    }

    @ViewBuilder
    private var content: some View {
        if openTasks.isEmpty {
            emptyState
        } else {
            List {
                Section {
                    ForEach(sorted) { task in
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
        }
    }

    private var sorted: [TodoTask] {
        openTasks.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return $0.order < $1.order
        }
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
