import SwiftUI
import SwiftData

/// "Upcoming" screen — incomplete tasks due in the next 14 days, grouped per day.
/// Mirrors real Todoist: a per-day list with "Tomorrow" / "Mon 21 Jun" section headers,
/// a centred empty state when nothing is scheduled, and no chrome beyond the system nav title.
struct UpcomingView: View {
    // Incomplete tasks only. SwiftData sorts the optional `dueDate` keypath with nils last.
    @Query(
        filter: #Predicate<TodoTask> { task in
            task.completedAt == nil
        },
        sort: \.dueDate
    )
    private var incomplete: [TodoTask]

    private let horizonDays = 14

    var body: some View {
        ZStack {
            TK.canvas.ignoresSafeArea()
            if buckets.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Upcoming")
        .navigationBarTitleDisplayMode(.large)
        .environment(\.hideRedundantDue, true)
    }

    // MARK: - Sections

    private var list: some View {
        List {
            // Subtitle header — sits at the very top of the list, just below the large title.
            Section {
                EmptyView()
            } header: {
                Text(subtitle)
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .textCase(nil)
                    .accessibilityIdentifier("upcoming-subtitle")
            }

            ForEach(buckets) { bucket in
                Section {
                    // Rows inlined (NOT a nested List) so day headers + rows share one grid.
                    ForEach(bucket.tasks) { task in
                        TaskRowView(task: task)
                            .listRowSeparatorTint(TK.hairlineSoft)
                    }
                } header: {
                    Text(bucket.label)
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                        .textCase(nil)
                        .accessibilityIdentifier("upcoming-day-header-\(bucket.idString)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
            .listRowBackground { if TK.isDarkGlass { Rectangle().fill(.thinMaterial) } else { TK.canvas } }
        .background { GlassPlanetBg() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityIdentifier("upcoming-empty-icon")
            Text("Nothing on the horizon")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
                .accessibilityIdentifier("upcoming-empty-title")
            Text("Tasks with due dates in the next 14 days will appear here.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("upcoming-empty-subtitle")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { GlassPlanetBg() }
    }

    // MARK: - Derived

    /// "Fri 20 Jun" — matches the TodayView subtitle style.
    private var subtitle: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Start of tomorrow — TodayView already owns today's tasks, so Upcoming starts tomorrow.
    private var horizonStart: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return cal.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// End of the 14th day out, exclusive upper bound for the date filter.
    private var horizonEnd: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return cal.date(byAdding: .day, value: horizonDays, to: today) ?? today
    }

    /// Buckets: one per day within the horizon, sorted ascending; each bucket's tasks sorted by priority then order.
    private var buckets: [DayBucket] {
        let cal = Calendar.current
        let start = horizonStart
        let end = horizonEnd

        let inWindow = incomplete.compactMap { task -> TodoTask? in
            guard let due = task.dueDate, due >= start, due < end else { return nil }
            return task
        }

        let grouped = Dictionary(grouping: inWindow) { task in
            cal.startOfDay(for: task.dueDate ?? .now)
        }

        return grouped.keys.sorted().map { day in
            let tasks = (grouped[day] ?? []).sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.order < rhs.order
            }
            return DayBucket(date: day, label: Self.label(for: day), tasks: tasks)
        }
    }

    private static func label(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

// MARK: - Day bucket

private struct DayBucket: Identifiable {
    let date: Date
    let label: String
    let tasks: [TodoTask]

    var id: Date { date }

    /// Stable string for accessibilityIdentifier (UUIDs/Date ids can't appear directly in identifiers).
    var idString: String {
        ISO8601DateFormatter().string(from: date)
    }
}

// MARK: - Preview
