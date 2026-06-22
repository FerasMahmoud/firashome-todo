import XCTest
@testable import Todo

/// NLParser unit tests — verify the natural-language quick-add parser extracts
/// the same fields the verified web SPA parser does (priority, project, labels,
/// today/tomorrow, weekdays, every-day/week/month/year, reminder shortcuts).
final class NLParserTests: XCTestCase {

    /// Fixed "now" so date assertions are deterministic regardless of when the
    /// test runs. Monday 2026-06-22 09:00 local.
    private let now: Date = {
        var c = Calendar.current
        c.timeZone = TimeZone.current
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 22
        comps.hour = 9; comps.minute = 0; comps.second = 0
        // 2026-06-22 is a Monday (weekday 2). Pin via weekday to be safe.
        comps.weekday = 2
        return c.date(from: comps)!
    }()

    private let fitech = Project(name: "FITech", colorHex: "1B8B6A")
    private let urgent = Label(name: "urgent")

    // MARK: - Priority

    func testPriorityP1() {
        let p = NLParser.parse("Email John p1", now: now)
        XCTAssertEqual(p.priority, 1)
        XCTAssertEqual(p.cleanTitle, "Email John")
    }

    func testPriorityP4IsDefault() {
        let p = NLParser.parse("Plain task", now: now)
        XCTAssertEqual(p.priority, 4)
    }

    func testPriorityDoesNotMatchInsideWord() {
        // "step1" must not be read as priority 1.
        let p = NLParser.parse("Finish step1 of the plan", now: now)
        XCTAssertEqual(p.priority, 4)
        XCTAssertEqual(p.cleanTitle, "Finish step1 of the plan")
    }

    // MARK: - Project + labels

    func testProjectAndLabels() {
        let p = NLParser.parse("Email John #FITech @urgent", now: now, projects: [fitech], labels: [urgent])
        XCTAssertEqual(p.project?.name, "FITech")
        XCTAssertEqual(p.labels.map(\.name), ["urgent"])
        XCTAssertEqual(p.cleanTitle, "Email John")
    }

    func testUnknownProjectStrippedButNotCreated() {
        let p = NLParser.parse("Thing #Nonexistent", now: now, projects: [])
        XCTAssertNil(p.project)
        XCTAssertEqual(p.cleanTitle, "Thing")
    }

    // MARK: - Dates

    func testToday() {
        let p = NLParser.parse("Call mom today", now: now)
        XCTAssertNotNil(p.dueDate)
        // "today" resolves to the same calendar day as the injected `now`
        // (NOT Calendar.isDateInToday, which depends on the real run date).
        XCTAssertTrue(Calendar.current.isDate(p.dueDate!, inSameDayAs: now))
    }

    func testTomorrow() {
        let p = NLParser.parse("Call mom tomorrow", now: now)
        XCTAssertNotNil(p.dueDate)
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        XCTAssertEqual(cal.startOfDay(for: p.dueDate!), cal.startOfDay(for: expected))
    }

    func testWeekdayAdvancesFuture() {
        // "friday" from a Monday → 4 days forward (Tue→Fri is +4; Mon→Fri is +4).
        let p = NLParser.parse("Ship friday", now: now)
        XCTAssertNotNil(p.dueDate)
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: p.dueDate!), 6) // Sunday=1 … Friday=6
    }

    // MARK: - Recurrence

    func testEveryWeek() {
        let p = NLParser.parse("Standup every week", now: now)
        XCTAssertEqual(p.recurrenceRule, "weekly")
        XCTAssertEqual(p.cleanTitle, "Standup")
    }

    func testEveryDay() {
        let p = NLParser.parse("Gym every day", now: now)
        XCTAssertEqual(p.recurrenceRule, "daily")
        XCTAssertEqual(p.cleanTitle, "Gym")
    }

    func testEveryMonth() {
        let p = NLParser.parse("Pay rent every month", now: now)
        XCTAssertEqual(p.recurrenceRule, "monthly")
    }

    func testNoRecurrenceByDefault() {
        let p = NLParser.parse("One-off task", now: now)
        XCTAssertNil(p.recurrenceRule)
    }

    // MARK: - Reminder shortcut

    func testReminder30m() {
        let p = NLParser.parse("Call back !30m", now: now)
        XCTAssertNotNil(p.reminderDate)
        XCTAssertEqual(p.reminderDate!.timeIntervalSince(now), 30 * 60, accuracy: 1)
        XCTAssertEqual(p.cleanTitle, "Call back")
    }

    // MARK: - Compound (the headline Todoist example)

    func testCompoundLine() {
        let p = NLParser.parse("Email John p1 tomorrow #FITech @urgent every week", now: now, projects: [fitech], labels: [urgent])
        XCTAssertEqual(p.priority, 1)
        XCTAssertEqual(p.project?.name, "FITech")
        XCTAssertEqual(p.labels.map(\.name), ["urgent"])
        XCTAssertEqual(p.recurrenceRule, "weekly")
        XCTAssertEqual(p.cleanTitle, "Email John")
    }
}
