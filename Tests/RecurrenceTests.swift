import XCTest
@testable import Todo

/// Recurrence + reminder-derivation tests. These power the recurring-roll-forward
/// (complete a recurring task → Repository spawns the next occurrence using
/// `nextDueDateAfterCompletion`) and the local-notification scheduler.
final class RecurrenceTests: XCTestCase {

    private let cal = Calendar.current
    private var base: Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: 22, hour: 9))!
    }

    private func recurring(_ kind: String, dueOffsetDays: Int = 0) -> TodoTask {
        let due = cal.date(byAdding: .day, value: dueOffsetDays, to: base)!
        return TodoTask(title: "Recur", dueDate: due, recurrence: kind)
    }

    func testDailyAdvancesOneDay() {
        let next = recurring("daily").nextDueDateAfterCompletion
        XCTAssertNotNil(next)
        XCTAssertEqual(cal.dateComponents([.day], from: base, to: next!).day, 1)
    }

    func testWeeklyAdvancesSevenDays() {
        let next = recurring("weekly").nextDueDateAfterCompletion
        XCTAssertEqual(cal.dateComponents([.day], from: base, to: next!).day, 7)
    }

    func testMonthlyAdvancesOneMonth() {
        let next = recurring("monthly").nextDueDateAfterCompletion
        XCTAssertEqual(cal.dateComponents([.month], from: base, to: next!).month, 1)
    }

    func testYearlyAdvancesOneYear() {
        let next = recurring("yearly").nextDueDateAfterCompletion
        XCTAssertEqual(cal.dateComponents([.year], from: base, to: next!).year, 1)
    }

    func testNilRecurrenceReturnsNil() {
        let oneOff = TodoTask(title: "Once", dueDate: base)
        XCTAssertNil(oneOff.nextDueDateAfterCompletion)
    }

    func testNilDueReturnsNil() {
        let noDue = TodoTask(title: "Undated", recurrence: "daily")
        XCTAssertNil(noDue.nextDueDateAfterCompletion)
    }

    func testNotifyAtCombinesDayAndTime() {
        let time = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 14, minute: 30))!
        let task = TodoTask(title: "Remind", dueDate: base, dueTime: time)
        let notify = task.notifyAt
        XCTAssertNotNil(notify)
        // notifyAt = base's day @ 14:30.
        XCTAssertEqual(cal.component(.day, from: notify!), cal.component(.day, from: base))
        XCTAssertEqual(cal.component(.hour, from: notify!), 14)
        XCTAssertEqual(cal.component(.minute, from: notify!), 30)
    }
}
