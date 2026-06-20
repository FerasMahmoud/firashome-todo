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

    /// When launched with `--screen=<id>` (screenshot mode), render that screen
    /// full-screen deterministically — bypassing the split-view so the UITest
    /// can capture each page without relying on sidebar tap discovery.
    private var screenshotScreen: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--screen=") }?
            .replacingOccurrences(of: "--screen=", with: "")
    }

    var body: some View {
        if let screen = screenshotScreen {
            screenshotBody(screen)
        } else {
            splitBody
        }
    }

    @ViewBuilder
    private var splitBody: some View {
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

    /// Full-screen single screen for screenshot capture.
    @ViewBuilder
    private func screenshotBody(_ screen: String) -> some View {
        if screen == "quickadd" {
            QuickAddView()
        } else {
            NavigationStack {
                detailView(NavDestination(screen: screen) ?? .today)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        AddTaskBar { showingQuickAdd = true }
                    }
                    .toolbar {
                        // Todoist-style nav chrome: menu (left), search + more (right).
                        ToolbarItem(placement: .topBarLeading) {
                            Button { } label: {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(TK.secondary)
                            }
                            .accessibilityLabel("Menu")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: 18) {
                                Button { } label: {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(TK.secondary)
                                }
                                Button { } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundStyle(TK.secondary)
                                }
                            }
                        }
                    }
            }
            .tint(TK.accent)
            .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let sel = selection { detailView(sel) } else { TodayView() }
    }

    @ViewBuilder
    private func detailView(_ sel: NavDestination) -> some View {
        switch sel {
        case .today:           TodayView()
        case .inbox:           InboxView()
        case .upcoming:        UpcomingView()
        case .filters:         FiltersView()
        case .projects:        ProjectsView()
        case .labels:          LabelsView()
        case .project(let id): ProjectDetailView(projectID: id)
        }
    }
}

extension NavDestination {
    init?(screen: String) {
        switch screen {
        case "today":    self = .today
        case "inbox":    self = .inbox
        case "upcoming": self = .upcoming
        case "filters":  self = .filters
        case "projects": self = .projects
        case "labels":   self = .labels
        default:         return nil
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.37))
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
