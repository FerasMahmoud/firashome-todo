import XCTest
@testable import Todo

/// TaskSort unit tests — the comparators power every list's ordering, so a
/// regression here reshuffles every screen. Verifies priority-then-order,
/// priority-then-due, due-then-order, and completion-recency.
final class TaskSortTests: XCTestCase {

    private func task(_ title: String, priority: Int = 4, order: Int = 0, dueOffsetDays: Int? = nil, completedDaysAgo: Int? = nil) -> TodoTask {
        let cal = Calendar.current
        let base = cal.date(from: DateComponents(year: 2026, month: 6, day: 22, hour: 9))!
        let due = dueOffsetDays.map { cal.date(byAdding: .day, value: $0, to: base)! }
        let completed = completedDaysAgo.map { cal.date(byAdding: .day, value: -$0, to: base)! }
        let t = TodoTask(title: title, dueDate: due, priority: priority, order: order)
        if let c = completed { t.completedAt = c }
        return t
    }

    func testPriorityThenOrder() {
        // P2 before P3 regardless of order; within a tier, lower order first.
        let p2b = task("P2-late", priority: 2, order: 5)
        let p3a = task("P3-early", priority: 3, order: 1)
        let p2a = task("P2-early", priority: 2, order: 1)
        let sorted = TaskSort.byPriorityThenOrder([p3a, p2b, p2a])
        XCTAssertEqual(sorted.map(\.title), ["P2-early", "P2-late", "P3-early"])
    }

    func testPriorityThenDueDate() {
        // Same priority → earlier due first; undated sinks to the end.
        let dated = task("dated P3", priority: 3, order: 0, dueOffsetDays: 2)
        let undated = task("undated P3", priority: 3, order: 0)
        let sorted = TaskSort.byPriorityThenDueDate([undated, dated])
        XCTAssertEqual(sorted.map(\.title), ["dated P3", "undated P3"])
    }

    func testByDueDateThenOrder() {
        let later = task("later", priority: 1, order: 0, dueOffsetDays: 5)
        let sooner = task("sooner", priority: 4, order: 9, dueOffsetDays: 1)
        let sorted = TaskSort.byDueDateThenOrder([later, sooner])
        XCTAssertEqual(sorted.map(\.title), ["sooner", "later"]) // due wins over priority
    }

    func testCompletionRecencyMostRecentFirst() {
        let old = task("old-done", completedDaysAgo: 10)
        let recent = task("recent-done", completedDaysAgo: 1)
        let sorted = TaskSort.byCompletionRecency([old, recent])
        XCTAssertEqual(sorted.map(\.title), ["recent-done", "old-done"])
    }
}
