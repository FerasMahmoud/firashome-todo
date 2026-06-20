import SwiftUI
import SwiftData

/// Top-level navigation destinations driven from the sidebar.
enum NavDestination: Hashable {
    case inbox
    case today
    case upcoming
    case filters
    case projects
    case labels
    case project(UUID)
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var selection: NavDestination? = .today
    @State private var showingQuickAdd = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detail
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AddTaskBar { showingQuickAdd = true }
                }
        }
        .tint(TK.accent)
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddView()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .today, nil:      TodayView()
        case .inbox:           InboxView()
        case .upcoming:        UpcomingView()
        case .filters:         FiltersView()
        case .projects:        ProjectsView()
        case .labels:          LabelsView()
        case .project(let id): ProjectDetailView(projectID: id)
        }
    }
}

/// Todoist's signature bottom "Add task" bar — full-width rounded row with a
/// red ＋ and muted "Add task" label, sitting above the home indicator.
struct AddTaskBar: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(TK.accent)
                Text("Add task")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(TK.secondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(TK.canvas)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(TK.hairlineSoft)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
        .accessibilityIdentifier("Add task")
    }
}

#Preview {
    RootView()
        .modelContainer(for: [TodoTask.self, Project.self, Label.self], inMemory: true)
}
