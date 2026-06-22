import SwiftUI
import SwiftData

/// Life Calendar — unified month grid showing tasks (red), habits done
/// (green), and countdowns (purple) as dots on each day. Tap a day to
/// see its items below. Same TK design system. SF Symbols only.
struct LifeCalendarView: View {
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil }) private var openTasks: [TodoTask]
    @Query private var habits: [Habit]
    @Query(sort: \CountdownEvent.targetDate) private var countdowns: [CountdownEvent]
    @State private var monthOffset = 0
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    private var cal = Calendar.current
    private var monthNames = ["January","February","March","April","May","June","July","August","September","October","November","December"]

    private var baseMonth: Date {
        cal.date(byAdding: .month, value: monthOffset, to: cal.startOfDay(for: .now))!
    }

    private func eventsFor(_ day: Date) -> (tasks: Int, habits: Int, countdowns: Int) {
        let ds = cal.startOfDay(for: day)
        let t = openTasks.filter { $0.dueDate.map { cal.isDate($0, inSameDayAs: ds) } ?? false }.count
        let h = habits.filter { habit in habit.completions.contains { cal.isDate($0, inSameDayAs: ds) } }.count
        let c = countdowns.filter { cal.isDate($0.targetDate, inSameDayAs: ds) }.count
        return (t, h, c)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 2) {
                    let days = daysInMonth()
                    ForEach(days, id: \.self) { day in
                        if let day {
                            let e = eventsFor(day)
                            let has = e.tasks > 0 || e.habits > 0 || e.countdowns > 0
                            VStack(spacing: 3) {
                                Text("\(cal.component(.day, from: day))")
                                    .font(.system(size: 13, weight: cal.isDateInToday(day) ? .heavy : .medium))
                                    .foregroundStyle(cal.isDate(day, inSameDayAs: selectedDay) ? .white : TK.ink)
                                HStack(spacing: 2) {
                                    if e.tasks > 0 { Circle().fill(TK.accent).frame(width: 5, height: 5) }
                                    if e.habits > 0 { Circle().fill(Color(hex: "1f9d5e")).frame(width: 5, height: 5) }
                                    if e.countdowns > 0 { Circle().fill(Color(hex: "9C27B0")).frame(width: 5, height: 5) }
                                }
                                .opacity(has ? 1 : 0)
                            }
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                            .background(cal.isDate(day, inSameDayAs: selectedDay) ? TK.accent : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { selectedDay = day }
                        } else {
                            Color.clear.frame(minHeight: 44)
                        }
                    }
                }
                .padding(14)

                // Selected day items
                let e = eventsFor(selectedDay)
                if e.tasks + e.habits + e.countdowns > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedDay, format: .dateTime.weekday().month().day())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TK.ink)
                            .padding(.horizontal, 4)
                        if e.tasks > 0 {
                            ForEach(openTasks.filter { $0.dueDate.map { cal.isDate($0, inSameDayAs: selectedDay) } ?? false }) { t in
                                itemRow(icon: "flag.fill", color: TK.accent, text: t.title, sub: "Task")
                            }
                        }
                        if e.habits > 0 {
                            ForEach(habits.filter { $0.completions.contains { cal.isDate($0, inSameDayAs: selectedDay) } }) { h in
                                itemRow(icon: "checkmark.circle.fill", color: Color(hex: "1f9d5e"), text: h.name, sub: "Habit done")
                            }
                        }
                        if e.countdowns > 0 {
                            ForEach(countdowns.filter { cal.isDate($0.targetDate, inSameDayAs: selectedDay) }) { c in
                                itemRow(icon: "calendar", color: Color(hex: "9C27B0"), text: c.title, sub: "Countdown")
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TK.canvas)
            .navigationTitle("Life Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .principal) { Text("\(monthNames[cal.component(.month, from: baseMonth) - 1]) \(cal.component(.year, from: baseMonth))").font(.system(size: 15, weight: .bold)) }
                ToolbarItem(placement: .topBarTrailing) { Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") } }
            }
        }
    }

    private func itemRow(icon: String, color: Color, text: String, sub: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 26, height: 26).background(TK.grouped).clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) { Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(TK.ink); Text(sub).font(.system(size: 11)).foregroundStyle(TK.secondary) }
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func daysInMonth() -> [Date?] {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: baseMonth))!
        let firstWkday = cal.component(.weekday, from: first) - 1
        let count = cal.range(of: .day, in: .month, for: first)!.count
        var arr: [Date?] = Array(repeating: nil, count: firstWkday)
        for i in 1...count { arr.append(cal.date(byAdding: .day, value: i - 1, to: first)) }
        return arr
    }
}
