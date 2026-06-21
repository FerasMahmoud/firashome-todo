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

    @Environment(\.modelContext) private var ctx
    @State private var selectedDay: Date?

    private let horizonDays = 14

    var body: some View {
        ZStack {
            TK.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                dateStrip
                if filteredBuckets.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationTitle("Upcoming")
        .navigationBarTitleDisplayMode(.large)
        .environment(\.hideRedundantDue, true)
    }

    // MARK: - Date strip

    private var dateStrip: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stripDays, id: \.self) { day in
                        DatePill(
                            day: day,
                            isToday: Calendar.current.isDateInToday(day),
                            isSelected: isSelected(day),
                            onTap: { toggle(day) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            Rectangle()
                .fill(TK.hairline)
                .frame(height: 0.5)
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .accessibilityIdentifier("upcoming-date-strip")
    }

    /// 14 days starting from today — the strip window. Mirrors `horizonDays`.
    /// `buckets` uses `horizonStart = tomorrow` because TodayView owns today's tasks;
    /// the strip still includes today so the user can drill into it.
    private var stripDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<horizonDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
        }
    }

    private func isSelected(_ day: Date) -> Bool {
        guard let selected = selectedDay else { return false }
        return Calendar.current.isDate(selected, inSameDayAs: day)
    }

    /// Tap-to-select with tap-to-deselect on the active pill — keeps one-tap escape hatch.
    private func toggle(_ day: Date) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: day)
        if let selected = selectedDay, cal.isDate(selected, inSameDayAs: startOfDay) {
            selectedDay = nil
        } else {
            selectedDay = startOfDay
        }
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

            ForEach(filteredBuckets) { bucket in
                Section {
                    // Rows inlined (NOT a nested List) so day headers + rows share one grid.
                    ForEach(bucket.tasks) { task in
                        TaskRowView(task: task)
                            .listRowSeparatorTint(TK.hairlineSoft)
                    }
                    .onMove { source, destination in
                        move(in: bucket, from: source, to: destination)
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)
            
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
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
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
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

    /// Buckets for display — when a pill is selected, narrow to that day's tasks;
    /// if nothing matches, fall back to the full upcoming list (never an empty body).
    private var filteredBuckets: [DayBucket] {
        guard let day = selectedDay else { return buckets }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: day)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let onDay = incomplete.compactMap { task -> TodoTask? in
            guard let due = task.dueDate, due >= startOfDay, due < endOfDay else { return nil }
            return task
        }
        guard !onDay.isEmpty else { return buckets }
        let sorted = onDay.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.order < rhs.order
        }
        return [DayBucket(date: startOfDay, label: Self.label(for: startOfDay), tasks: sorted)]
    }

    private static func label(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: - Reorder

    /// Drag-to-reorder within a single day's bucket. Cross-day moves would
    /// require rewriting the due date, so we scope each section's reorder to
    /// its own bucket.
    private func move(in bucket: DayBucket, from source: IndexSet, to destination: Int) {
        var reordered = bucket.tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        Repository.reorder(reordered, in: ctx)
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

// MARK: - Date pill

/// One cell in the horizontal upcoming date strip.
/// Visuals: today always fills with `TK.accent`; selected non-today fills with `TK.ink`;
/// unselected sits on `TK.card` with a hairline border.
private struct DatePill: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(weekday)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                Text(dayNumber)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(textColor)
            .frame(width: 52, height: 64)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: TK.rPill, style: .continuous))
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: TK.rPill, style: .continuous)
                        .strokeBorder(TK.hairline, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: TK.rPill, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("upcoming-date-pill-\(dayNumber)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var weekday: String {
        day.formatted(.dateTime.weekday(.abbreviated))
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day))
    }

    private var textColor: Color {
        isToday || isSelected ? TK.canvas : TK.ink
    }

    private var backgroundColor: Color {
        if isToday { return TK.accent }
        if isSelected { return TK.ink }
        return TK.card
    }

    private var showBorder: Bool {
        !isToday && !isSelected
    }

    private var accessibilityLabel: String {
        let dateText = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if isToday { return "Today, \(dateText)" }
        if isSelected { return "Selected, \(dateText)" }
        return dateText
    }
}
