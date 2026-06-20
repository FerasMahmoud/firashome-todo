import SwiftUI
import SwiftData

/// Top-level navigation destinations driven from the sidebar.
enum NavDestination: Hashable {
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
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            showingQuickAdd = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(TK.accent)
                        }
                        .accessibilityLabel("Add task")
                    }
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
        case .upcoming:        UpcomingView()
        case .filters:         FiltersView()
        case .projects:        ProjectsView()
        case .labels:          LabelsView()
        case .project(let id): ProjectDetailView(projectID: id)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [TodoTask.self, Project.self, Label.self], inMemory: true)
}
