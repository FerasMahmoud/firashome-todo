import SwiftUI
import SwiftData
import Charts

/// "This week" productivity card — 7 daily bars of completed-task counts,
/// plus a total and a consecutive-day streak.
///
/// Data source: `TodoTask.completedAt`. All completed tasks are fetched once
/// via `@Query` and bucketed client-side. The data volume is tiny (a few
/// hundred entries even after years of use) and the alternative — one
/// predicate per day — would have to be revalidated on every mutation.
///
/// Light theme, `TK.*` tokens, SF Symbols only. iOS 17+ (SwiftData + Charts).
struct ProductivityChartView: View {
    /// Every task that has ever been completed. We do all bucketing in
    /// Swift so the chart's x-axis stays contiguous (Chart collapses empty
    /// days if we don't pre-fill them).
    @Query(filter: #Predicate<TodoTask> { $0.completedAt != nil })
    private var completed: [TodoTask]

    private let cal: Calendar = .current
    /// Captured at init so re-renders don't shift the window each tick.
    private let today: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerCard
            chartCard
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TK.canvas)
        .accessibilityIdentifier("productivity-root")
    }

    // MARK: - Header

    private var headerCard: some View {
        let total = buckets.reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(TK.title)
                    .foregroundStyle(TK.ink)
                Spacer()
                Text("\(total)")
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(TK.ink)
                    .accessibilityIdentifier("productivity-total")
            }
            HStack(spacing: 6) {
                Text(total == 1 ? "task completed" : "tasks completed")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                if streak > 0 {
                    Text("\u{00B7}")
                        .font(TK.subhead)
                        .foregroundStyle(TK.secondary)
                        .accessibilityHidden(true)
                    streakPill
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(TK.card)
        .clipShape(RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary(total: total))
    }

    private var streakPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TK.accent)
                .accessibilityHidden(true)
            Text("\(streak) day streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TK.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(TK.accent.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel("\(streak) day streak")
        .accessibilityIdentifier("productivity-streak")
    }

    private func accessibilitySummary(total: Int) -> String {
        let totalPart = "\(total) \(total == 1 ? "task" : "tasks") completed this week"
        if streak > 0 {
            return "\(totalPart). \(streak) day streak."
        }
        return totalPart
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartCard: some View {
        if buckets.allSatisfy({ $0.count == 0 }) {
            emptyCard
        } else {
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Day", bucket.date, unit: .day),
                    y: .value("Tasks", bucket.count)
                )
                .foregroundStyle(TK.accent)
                .cornerRadius(4)
                .accessibilityLabel("\(bucket.label): \(bucket.count) completed")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine().foregroundStyle(TK.hairlineSoft)
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(TK.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(TK.hairlineSoft)
                    AxisValueLabel().foregroundStyle(TK.secondary)
                }
            }
            .frame(height: 180)
            .padding(16)
            .background(TK.card)
            .clipShape(RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
            .accessibilityIdentifier("productivity-chart")
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("No completions this week")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Finish a task to start your streak.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(TK.card)
        .clipShape(RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("productivity-empty")
    }

    // MARK: - Bucketing

    /// One bucket per day in the 7-day window, oldest first. Pre-filled with
    /// zeros so the chart's x-axis is contiguous; Chart would otherwise
    /// collapse the missing days and the labels would skip around.
    private var buckets: [DayBucket] {
        let days = (0..<7).reversed().compactMap { i in
            cal.date(byAdding: .day, value: -i, to: today)
        }
        var counts: [Date: Int] = [:]
        for task in completed {
            guard let at = task.completedAt else { continue }
            let day = cal.startOfDay(for: at)
            if days.contains(day) {
                counts[day, default: 0] += 1
            }
        }
        return days.map { DayBucket(date: $0, count: counts[$0] ?? 0) }
    }

    /// Consecutive days, walking back from today, where at least one task
    /// was completed. Stops at the first empty day — a streak is "alive
    /// only if it includes today" (matches Duolingo / Apple Health ring).
    private var streak: Int {
        var count = 0
        for bucket in buckets.reversed() {
            if bucket.count == 0 { break }
            count += 1
        }
        return count
    }
}

/// One bar's worth of data. `label` is precomputed so the view body stays
/// free of date-arithmetic.
private struct DayBucket: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
    var label: String { date.formatted(.dateTime.weekday(.abbreviated)) }
}

#if DEBUG
#Preview("With data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TodoTask.self, configurations: config)
    let ctx = container.mainContext
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)

    // Seed 7 days of completions — a 3-day streak ending today.
    let pattern: [Int] = [2, 1, 0, 3, 4, 2, 5]
    for (offset, n) in pattern.enumerated() {
        for i in 0..<n {
            let t = TodoTask(title: "Seed task \(offset)-\(i)", priority: 4, order: offset * 10 + i)
            t.completedAt = cal.date(byAdding: .day, value: -(pattern.count - 1 - offset), to: today)
                .flatMap { cal.date(byAdding: .hour, value: 9 + i, to: $0) }
            ctx.insert(t)
        }
    }
    // One open task to prove the query filters correctly.
    let open = TodoTask(title: "Still open", priority: 2, order: 999)
    ctx.insert(open)

    return ProductivityChartView()
        .modelContainer(container)
}

#Preview("Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TodoTask.self, configurations: config)
    return ProductivityChartView()
        .modelContainer(container)
}
#endif
