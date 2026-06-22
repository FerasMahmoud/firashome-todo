import SwiftUI
import SwiftData

/// Top-level navigation destinations driven from the sidebar.
enum NavDestination: Hashable {
    case inbox
    case today
    case upcoming
    case calendar
    case activity
    case productivity
    case search
    case filters
    case projects
    case labels
    case account
    case settings
    case habits
    case countdowns
    case lifeCalendar
    case routine
    case project(UUID)
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var selection: NavDestination? = .today
    @State private var showingQuickAdd = false
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var theme = ThemeManager.shared
    /// Observed so the body's `.animation(value: density.mode.rawValue)`
    /// fires when the user flips density from Settings — without this the
    /// view body never re-renders on a density change.
    @ObservedObject private var density = DensityManager.shared

    /// When launched with `--screen=<id>` (screenshot mode), render that screen
    /// full-screen deterministically — bypassing the split-view so the UITest
    /// can capture each page without relying on sidebar tap discovery.
    private var screenshotScreen: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--screen=") }?
            .replacingOccurrences(of: "--screen=", with: "")
    }

    /// Dimmed planet background — shows behind transparent (dark glass) content.
    @ViewBuilder
    private var planetBackground: some View {
        if TK.isDarkGlass, let url = Bundle.main.url(forResource: "planet", withExtension: "jpg"), let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .brightness(-0.12)
                .overlay(Color.black.opacity(0.22).ignoresSafeArea())
        }
    }

    var body: some View {
        Group {
            if let screen = screenshotScreen {
                screenshotBody(screen)
            } else {
                splitBody
            }
        }
        .background(planetBackground)
        .preferredColorScheme(TK.isDarkGlass ? .dark : .light)
        // Cascade theme + density changes through the scene. `SettingsView`
        // also carries a matching `.animation` on its appearance section so
        // the picker itself slides — this one handles the rest of the tree.
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: theme.raw)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: density.mode.rawValue)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--theme=darkglass") {
                ThemeManager.shared.raw = AppTheme.darkGlass.rawValue
            } else if args.contains("--theme=light") {
                ThemeManager.shared.raw = AppTheme.light.rawValue
            }
        }
    }

    @ViewBuilder
    private var splitBody: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detail
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AddTaskBar(action: { showingQuickAdd = true }, screenSymbol: addSymbolForScreen)
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
        } else if screen == "taskdetail" {
            ScreenshotTaskDetail()
        } else if screen == "onboarding" {
            OnboardingView()
        } else {
            NavigationStack {
                detailView(NavDestination(screen: screen) ?? .today)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        AddTaskBar(action: { showingQuickAdd = true }, screenSymbol: addSymbol(for: screen))
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
        case .calendar:        CalendarView()
        case .activity:        ActivityLogView()
        case .productivity:    ProductivityChartView()
        case .search:          SearchView()
        case .filters:         FiltersView()
        case .projects:        ProjectsView()
        case .labels:          LabelsView()
        case .account:         AccountView()
        case .settings:        SettingsView()
        case .habits:          HabitsView()
        case .countdowns:      CountdownsView()
        case .lifeCalendar:    LifeCalendarView()
        case .routine:         RoutineBoardView()
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
        case "calendar":     self = .calendar
        case "activity":     self = .activity
        case "productivity": self = .productivity
        case "search":       self = .search
        case "filters":  self = .filters
        case "projects": self = .projects
        case "labels":   self = .labels
        case "account":  self = .account
        case "settings": self = .settings
        case "habits":   self = .habits
        case "countdowns": self = .countdowns
        case "lifecalendar": self = .lifeCalendar
        case "routine":   self = .routine
        default:         return nil
        }
    }
}

/// Todoist's signature bottom "Add task" bar — full-width rounded row with a
/// red ＋ and muted "Add task" label, sitting above the home indicator.
///
/// The leading symbol swaps with `screenSymbol` so the button telegraphs
/// what it'll add (a task, a task inside a project, or a task carrying a
/// label). The swap is animated with `.symbolEffect(.bounce)` for the
/// bounce kick and `.contentTransition(.symbolEffect(.replace))` for the
/// smooth morph between glyphs; the wrapping `.animation(.spring)` settles
/// the rest of the row (padding, label) on the same beat.
struct AddTaskBar: View {
    let action: () -> Void
    /// SF Symbol name for the leading icon. Defaults to `plus.circle` so
    /// the existing screenshot-mode + preview call sites keep working.
    var screenSymbol: String = "plus.circle"

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: screenSymbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(TK.accent)
                    .symbolEffect(.bounce, value: screenSymbol)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text("Add task")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(TK.secondary)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .glassBar()
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(TK.hairlineSoft)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: screenSymbol)
        .accessibilityLabel("Add task")
        .accessibilityIdentifier("Add task")
    }
}

// MARK: - Add-symbol derivation

extension RootView {
    /// SF Symbol for `AddTaskBar` based on the current `selection`. Mapping:
    ///   - any project screen  → `folder.badge.plus`
    ///   - the labels screen    → `tag.fill`
    ///   - everything else      → `plus.circle`
    /// Default keeps the existing bar for Today / Inbox / Upcoming / Calendar
    /// / search / filters / activity / productivity / account / settings —
    /// i.e. all the screens that aren't project- or label-scoped.
    fileprivate var addSymbolForScreen: String {
        switch selection {
        case .projects, .project: return "folder.badge.plus"
        case .labels:             return "tag.fill"
        default:                  return "plus.circle"
        }
    }

    /// Same mapping as `addSymbolForScreen`, but driven by the screenshot
    /// `--screen=` string so the dynamic icon shows up in the capture too.
    fileprivate func addSymbol(for screen: String) -> String {
        switch screen {
        case "projects": return "folder.badge.plus"
        case "labels":   return "tag.fill"
        default:         return "plus.circle"
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [TodoTask.self, Project.self, Label.self], inMemory: true)
}

/// Screenshot helper: renders TaskDetailView with the first seeded task (shows subtasks).
struct ScreenshotTaskDetail: View {
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var tasks: [TodoTask]

    var body: some View {
        NavigationStack {
            if let task = tasks.first(where: { $0.title == "Review Qiddiya drone survey brief" }) ?? tasks.first {
                TaskDetailView(task: task)
            } else {
                Text("No task").foregroundStyle(TK.secondary)
            }
        }
    }
}
