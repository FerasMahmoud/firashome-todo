import SwiftUI
import SwiftData

/// "Inbox" screen — every open task with no project assigned. Mirrors Todoist's
/// Inbox: the catch-all bucket that sits at the top of the sidebar.
struct InboxView: View {
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil && $0.project == nil })
    private var openTasks: [TodoTask]

    var body: some View {
        content
            .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
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
                } header: {
                    Text("Tasks")
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        .listRowBackground(GlassRowBg())
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
