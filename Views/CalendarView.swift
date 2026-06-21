import SwiftUI
import SwiftData

/// Month-grid calendar. Tapping a day reveals that day's tasks below the grid.
///
/// The query fetches every task that has a `dueDate` (open or completed) — the
/// dots are then a literal fingerprint of what's scheduled on each day, and the
/// list below shows the same set for the selected day. Bucketing into a
/// `[startOfDay: [TodoTask]]` map once per render is cheaper than re-filtering
/// per cell, and the data volume is small.
///
/// `Date.now` is captured in `init()` (one-shot at view construction) and stored
/// in `@State` so the visible-month / selected-day defaults are stable across
/// body re-evaluations — never read `Date.now` inside `var body`.
///
/// Light theme, `TK.*` tokens, SF Symbols only. iOS 17 (SwiftData).
struct CalendarView: View {
    /// SwiftData model context — captured so the view conforms to the spec even
    /// though day taps and chevron taps are pure local state today.
    @Environment(\.modelContext) private var context

    /// Every task that has a due date — drives both the per-day dots and the
    /// selected-day list. Predicate uses SwiftData's supported shape only.
    @Query(filter: #Predicate<TodoTask> { $0.dueDate != nil })
    private var allTasks: [TodoTask]

    /// First day of the month currently in view. Tapping the chevrons rewinds
    /// or advances by one calendar month; the value is normalised to start-of-day.
    @State private var visibleMonth: Date

    /// The day the user tapped. Defaults to today on first appear so the
    /// task list below is non-empty whenever today has any due tasks.
    @State private var selectedDay: Date?

    private let cal: Calendar = .current

    init() {
        let cal = Calendar.current
        let now = Date.now
        let start = cal.startOfDay(for: now)
        self._visibleMonth = State(initialValue: start)
        self._selectedDay = State(initialValue: start)
    }

    var body: some View {
        List {
            // Grid — static chrome for the screen, lives in a single list row
            // so the whole screen shares one scroll container and the
            // `.listStyle(.plain)` / `.scrollContentBackground(.hidden)`
            // modifiers below apply uniformly.
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    monthHeader
                    weekdayHeader
                    grid
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(TK.canvas)
            }

            // Selected-day list — actual task rows. Hidden when the day is
            // empty with a soft "Nothing scheduled" placeholder.
            if let day = selectedDay {
                let tasks = tasksForDay(day)
                Section {
                    if tasks.isEmpty {
                        emptyDayRow
                            .listRowSeparator(.hidden)
                            .listRowBackground(TK.canvas)
                    } else {
                        ForEach(tasks) { task in
                            TaskRowView(task: task)
                                .listRowSeparator(.hidden)
                                .listRowBackground(TK.canvas)
                        }
                    }
                } header: {
                    dayHeader(day, count: tasks.count)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TK.canvas)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TK.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("calendar-prev-month")

            Spacer()

            Text(monthTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TK.ink)
                .accessibilityIdentifier("calendar-month-title")

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TK.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("calendar-next-month")
        }
        .padding(.horizontal, 16)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TK.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }

    // MARK: - Grid

    private var grid: some View {
        let cells = monthCells
        return VStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if idx < cells.count {
                            dayCell(cells[idx])
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: DayCell) -> some View {
        let isToday = cal.isDateInToday(cell.date)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: cell.date) } ?? false
        let isInVisibleMonth = cal.isDate(cell.date, equalTo: visibleMonth, toGranularity: .month)

        Button {
            selectedDay = cell.date
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: cell.date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .medium))
                    .foregroundStyle(textColor(isInVisibleMonth: isInVisibleMonth, isToday: isToday, isSelected: isSelected))
                dotsAndOverflow(for: cell, isInVisibleMonth: isInVisibleMonth)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? TK.accent.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday && !isSelected ? TK.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: cell, isSelected: isSelected))
        .accessibilityIdentifier("calendar-day-\(cell.isoDay)")
    }

    /// Up to 3 dots, each colored by the corresponding task's priority (via
    /// `TK.priority`). When the day has more than 3 due tasks, append a small
    /// `+N` label so the cell stays compact at a glance.
    @ViewBuilder
    private func dotsAndOverflow(for cell: DayCell, isInVisibleMonth: Bool) -> some View {
        let tasks = cell.tasks
        let visible = tasks.prefix(3)
        let overflow = tasks.count - visible.count
        HStack(spacing: 2) {
            ForEach(Array(visible), id: \.id) { task in
                Circle()
                    .fill(TK.priority(task.priority))
                    .frame(width: 5, height: 5)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isInVisibleMonth ? TK.secondary : TK.secondary.opacity(0.45))
            }
        }
        .frame(height: 6)
        .opacity(isInVisibleMonth ? 1 : 0.35)
        .accessibilityHidden(true)
    }

    // MARK: - Day section

    @ViewBuilder
    private func dayHeader(_ day: Date, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
                .textCase(nil)
            if count > 0 {
                Text("· \(count)")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("calendar-day-header")
    }

    private var emptyDayRow: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("Nothing scheduled")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendar-empty-day")
    }

    // MARK: - Helpers

    private struct DayCell: Identifiable {
        let id: String
        let date: Date
        let tasks: [TodoTask]
        var isoDay: String { id }
    }

    /// One-shot bucketing of all due tasks by start-of-day. Computed per
    /// render — cheap for the seed volume, and avoids per-cell `isSameDay` scans.
    private var bucketedTasks: [Date: [TodoTask]] {
        var result: [Date: [TodoTask]] = [:]
        for task in allTasks {
            guard let due = task.dueDate else { continue }
            let day = cal.startOfDay(for: due)
            result[day, default: []].append(task)
        }
        return result
    }

    /// Ordered 7×6 grid of cells (always 42) for the visible month. Leading
    /// cells before day 1 belong to the previous month; trailing cells belong
    /// to the next. Only in-month cells get non-empty task lists, the rest
    /// render as muted placeholders so the grid still reads as a 6-row block.
    private var monthCells: [DayCell] {
        guard let monthInterval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30
        let total = 42
        let trailing = total - leading - daysInMonth
        let bucket = bucketedTasks
        var cells: [DayCell] = []

        // Leading (prev month) cells.
        if leading > 0,
           let leadingStart = cal.date(byAdding: .day, value: -leading, to: firstOfMonth) {
            for i in 0..<leading {
                let d = cal.date(byAdding: .day, value: i, to: leadingStart)!
                cells.append(DayCell(id: isoDay(d), date: d, tasks: []))
            }
        }
        // In-month cells — look up bucket by start-of-day.
        for i in 0..<daysInMonth {
            let d = cal.date(byAdding: .day, value: i, to: firstOfMonth)!
            let tasks = bucket[cal.startOfDay(for: d)] ?? []
            cells.append(DayCell(id: isoDay(d), date: d, tasks: tasks))
        }
        // Trailing (next month) cells.
        if trailing > 0 {
            let lastInMonth = cal.date(byAdding: .day, value: daysInMonth - 1, to: firstOfMonth)!
            for i in 1...trailing {
                let d = cal.date(byAdding: .day, value: i, to: lastInMonth)!
                cells.append(DayCell(id: isoDay(d), date: d, tasks: []))
            }
        }
        return cells
    }

    /// Tasks for the selected day, sorted by priority (P1 first) then manual
    /// `order`. Mirrors the Today/Upcoming sort so the day list reads the
    /// same way users already see elsewhere in the app.
    private func tasksForDay(_ day: Date) -> [TodoTask] {
        let dayStart = cal.startOfDay(for: day)
        return allTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return cal.startOfDay(for: due) == dayStart
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.order < rhs.order
            }
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private func shiftMonth(by months: Int) {
        if let next = cal.date(byAdding: .month, value: months, to: visibleMonth) {
            visibleMonth = cal.startOfDay(for: next)
        }
    }

    private func textColor(isInVisibleMonth: Bool, isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return TK.accent }
        if !isInVisibleMonth { return TK.secondary.opacity(0.45) }
        if isToday { return TK.accent }
        return TK.ink
    }

    private func isoDay(_ date: Date) -> String {
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private func accessibilityLabel(for cell: DayCell, isSelected: Bool) -> String {
        let datePart = cell.date.formatted(date: .complete, time: .omitted)
        let countPart = cell.tasks.count == 0 ? "no tasks" : "\(cell.tasks.count) tasks"
        let sel = isSelected ? ", selected" : ""
        return "\(datePart), \(countPart)\(sel)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TodoTask.self, Project.self, Label.self,
        configurations: config
    )
    let ctx = container.mainContext
    let cal = Calendar.current
    let now = Date()
    let monthStart = cal.startOfDay(for: now)

    let work = Project(name: "FITech", colorHex: "246FE0", order: 0, isFavorite: true)
    let home = Project(name: "Personal", colorHex: "E03982", order: 1)
    ctx.insert(work)
    ctx.insert(home)

    // Spread tasks across the visible month so the grid shows a mix of
    // empty days, single dots, multi-dot days, and a "+N" overflow.
    let seeds: [(String, Int, Int, Project?)] = [
        ("Review Q3 drone proposal with Firas", 1, 0, work),
        ("Send weekly status report",            2, 0, work),
        ("Coffee with M",                        4, 1, home),
        ("Buy groceries",                        3, 2, home),
        ("Gym",                                  4, 3, nil),
        ("Read iOS 26 release notes",            2, 4, work),
        ("Pack for Riyadh",                      1, 5, home),
        ("Pay rent",                             2, 5, home),
        ("Call mom",                             3, 5, home),
        ("Audit Q2 numbers",                     1, 5, work),
        ("Update viewkeeper CI",                 2, 5, work),
        ("Renew passport",                       3, 6, home),
        ("Plan weekend",                         4, 7, nil),
        ("Skeptic build session",                1, 9, work),
        ("Dinner reservation",                   2, 11, home),
        ("Wrangle Telegram bots",                2, 14, work),
    ]
    for (i, s) in seeds.enumerated() {
        let due = cal.date(byAdding: .day, value: s.2, to: monthStart) ?? now
        ctx.insert(TodoTask(title: s.0, dueDate: due, priority: s.1, order: i, project: s.3))
    }

    return CalendarView()
        .modelContainer(container)
}
#endif
