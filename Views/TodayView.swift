import SwiftUI
import SwiftData

/// "Today" screen — Todoist-style list of open tasks due today or earlier.
///
/// Renders a large "Today" navigation title with today's date as a small
/// subtitle, then two sections: a red-tinted "Overdue" section followed by
/// a muted "Today" section. When both buckets are empty, shows a centered
/// checkmark empty state.
struct TodayView: View {
    /// All open (uncompleted) tasks. We bucket them into Overdue / Today in
    /// Swift rather than in the `#Predicate`, because date arithmetic in the
    /// predicate macro is awkward across SDKs and the data volume here is small.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    /// Tasks completed today (for the progress ring).
    @Query(filter: #Predicate<TodoTask> { $0.completedAt != nil })
    private var completedTasks: [TodoTask]

    // Cached at init so the list view is cheap to recompute when the query
    // refreshes. `Date.now` and `Calendar.current` would otherwise re-evaluate
    // on every body invocation.
    private let startOfToday: Date
    private let startOfTomorrow: Date
    private let dateSubtitle: String

    init() {
        let cal = Calendar.current
        let now = Date.now
        let start = cal.startOfDay(for: now)
        self.startOfToday = start
        self.startOfTomorrow = cal.date(byAdding: .day, value: 1, to: start) ?? start

        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEE d MMM"
        self.dateSubtitle = f.string(from: now)
    }

    var body: some View {
        content
            .background(TK.canvas)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .environment(\.hideRedundantDue, true)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if overdue.isEmpty && todays.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Date subtitle + task count — sits under the large "Today" nav title.
                Text("\(dateSubtitle) · \(todays.count + overdue.count) tasks")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("today-date-subtitle")

                // Glassy progress ring.
                ProgressRing(done: doneToday, total: todays.count + doneToday)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                taskList
            }
        }
    }

    private var taskList: some View {
        List {
            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { task in
                        TaskRowView(task: task)
                            .listRowSeparatorTint(TK.hairlineSoft)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(TK.sectionHeader)
                            .foregroundStyle(TK.accent)
                            .accessibilityHidden(true)
                        Text("Overdue")
                            .font(TK.sectionHeader)
                            .foregroundStyle(TK.accent)
                    }
                    .textCase(nil)
                    .accessibilityIdentifier("today-section-overdue")
                }
            }
            if !todays.isEmpty {
                // No "Today" section header — the large nav title already says Today (Todoist style).
                Section {
                    ForEach(todays) { task in
                        TaskRowView(task: task)
                            .listRowSeparatorTint(TK.hairlineSoft)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(TK.canvas)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("You're all clear for today")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
                .multilineTextAlignment(.center)
            Text("Tap + to add a task")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-empty-state")
        .accessibilityLabel("You're all clear for today. Tap + to add a task.")
    }

    // MARK: - Bucketing

    /// Open tasks whose due date is strictly before the start of today.
    /// Sorted earliest-due-first, then by manual `order`.
    private var overdue: [TodoTask] {
        openTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return due < startOfToday
            }
            .sorted { lhs, rhs in
                let l = lhs.dueDate ?? .distantFuture
                let r = rhs.dueDate ?? .distantFuture
                if l != r { return l < r }
                return lhs.order < rhs.order
            }
    }

    /// Open tasks due any time today. Sorted by priority (P1 first), then manual order.
    private var todays: [TodoTask] {
        openTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.order < rhs.order
            }
    }

    /// Tasks completed today (for the progress ring).
    private var doneToday: Int {
        completedTasks.filter { Calendar.current.isDateInToday($0.completedAt ?? .distantPast) }.count
    }
}



// perf-probe
