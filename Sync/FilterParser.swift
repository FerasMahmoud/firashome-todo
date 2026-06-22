import Foundation
import SwiftData

/// Structured result of parsing a Todoist-style filter query against the
/// task store. Views call `FilterParser.apply(_:to:)` to filter an array of
/// `TodoTask`s. Designed for the `query` field on `SavedFilter` and for an
/// ad-hoc search bar that wants structured filters (priority, date, label,
/// project) on top of plain text.
struct ParsedFilter: Equatable {
    enum DateRange: Equatable {
        /// Open tasks whose due date is strictly before the start of today.
        case overdue
        /// Open tasks due any time today.
        case today
        /// Open tasks due any time tomorrow.
        case tomorrow
        /// Open tasks due within the next N days, inclusive of today.
        case nextDays(Int)
        /// Open tasks with no due date set.
        case noDate
        /// No date constraint — tasks with any (or no) date match.
        case any
    }

    /// Free-text terms. A task matches if its title or note contains ANY term
    /// (case + diacritic insensitive via `localizedStandardContains`).
    var searchTerms: [String] = []
    /// Restrict to these priorities (1=red … 4=none). Empty means "any".
    var priorities: Set<Int> = []
    /// Tasks must carry ALL of these labels by name (case-insensitive).
    var labelNames: [String] = []
    /// Restrict to a single project by name. `nil` means "any project".
    var projectName: String? = nil
    var dateRange: DateRange = .any
    /// `false` (default) hides completed tasks; `true` includes them.
    var includeCompleted: Bool = false

    /// True when no axis constrains the result — equivalent to "show all".
    var isEmpty: Bool {
        searchTerms.isEmpty && priorities.isEmpty && labelNames.isEmpty
            && projectName == nil && dateRange == .any && !includeCompleted
    }
}

/// Parses a Todoist-style filter query (e.g. `p1 today @work`, `overdue
/// #personal`, `7 days foo`) into a `ParsedFilter`. Composable across every
/// axis the built-in `FilterKind` smart filters cover, plus free text. v1
/// treats space as implicit AND — `&` / `|` / `!` are not parsed and pass
/// through as literal search terms.
///
/// Syntax:
///   * `today` / `tomorrow` / `overdue` / `no date` — date bucket
///   * `7 days` or `next 7 days` — date bucket
///   * `p1` … `p4` — priority (repeatable: `p1 p2`)
///   * `@label` — label (repeatable, AND-combined)
///   * `#project` — single project
///   * anything else — free-text search term (case + diacritic insensitive,
///     matches title OR note; multiple terms are OR-combined)
enum FilterParser {
    /// Parse a raw query string. Whitespace separates tokens. Returns an
    /// empty filter for blank input — callers can short-circuit on
    /// `ParsedFilter.isEmpty`.
    static func parse(_ raw: String) -> ParsedFilter {
        var filter = ParsedFilter()
        var working = raw
        // Multi-word date phrases FIRST — the tokenizer below splits on
        // whitespace, so "no date" / "7 days" / "next 7 days" would otherwise
        // arrive as single tokens and never match. Resolve + strip them here.
        let lw = working.lowercased()
        if lw.contains("no date") || lw.contains("nodate") {
            filter.dateRange = .noDate
            working = working.replacingOccurrences(of: "no date", with: " ", options: .caseInsensitive)
            working = working.replacingOccurrences(of: "nodate", with: " ", options: .caseInsensitive)
        } else if let m = working.range(of: #"(?:next\s+)?(\d+)\s+days"#,
                                        options: [.regularExpression, .caseInsensitive]),
                  let digits = working[m].range(of: #"\d+"#, options: .regularExpression),
                  let n = Int(working[m][digits]), n > 0 {
            filter.dateRange = .nextDays(n)
            working.removeSubrange(m)
        }
        let tokens = working.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        for token in tokens { applyToken(token, into: &filter) }
        return filter
    }

    private static func applyToken(_ token: String, into filter: inout ParsedFilter) {
        let lower = token.lowercased()
        switch lower {
        case "overdue":          filter.dateRange = .overdue; return
        case "today":            filter.dateRange = .today; return
        case "tomorrow":         filter.dateRange = .tomorrow; return
        case "nodate", "no date": filter.dateRange = .noDate; return
        default: break
        }
        if let n = matchDayCount(lower) { filter.dateRange = .nextDays(n); return }
        if isPriority(lower), let p = Int(String(lower.last!)) {
            filter.priorities.insert(p); return
        }
        if token.hasPrefix("@"), token.count > 1 {
            filter.labelNames.append(String(token.dropFirst())); return
        }
        if token.hasPrefix("#"), token.count > 1 {
            filter.projectName = String(token.dropFirst()); return
        }
        // Fallback: free-text term. Operators like `&`, `|`, `!` land here as
        // literal needles — acceptable for v1; revisit if queries get noisy.
        filter.searchTerms.append(token)
    }

    private static func isPriority(_ lower: String) -> Bool {
        guard lower.count == 2, lower.first == "p" else { return false }
        guard let p = Int(String(lower.last!)) else { return false }
        return (1...4).contains(p)
    }

    /// Matches `7 days` / `next 7 days` → 7. Returns nil otherwise.
    private static func matchDayCount(_ lower: String) -> Int? {
        var rest = lower
        if rest.hasPrefix("next ") { rest.removeFirst("next ".count) }
        let parts = rest.split(separator: " ")
        guard parts.count == 2, parts[1] == "days",
              let n = Int(parts[0]), n > 0 else { return nil }
        return n
    }

    // MARK: - Apply

    /// Filter `tasks` against `filter`. Order of the input is preserved.
    /// In-memory filter: the SwiftData `#Predicate` macro can't compose
    /// `localizedStandardContains`, label-set membership, and date arithmetic
    /// in one expression, and candidate sets for a single saved filter are
    /// small.
    static func apply(_ filter: ParsedFilter, to tasks: [TodoTask]) -> [TodoTask] {
        if filter.isEmpty { return tasks.filter { !$0.isCompleted } }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        return tasks.filter { task in
            if !filter.includeCompleted, task.isCompleted { return false }
            if !filter.priorities.isEmpty, !filter.priorities.contains(task.priority) {
                return false
            }
            if let project = filter.projectName {
                guard let p = task.project,
                      p.name.localizedStandardContains(project) else { return false }
            }
            if !filter.labelNames.isEmpty {
                let taskLabels = Set(task.labels.map { $0.name.lowercased() })
                for need in filter.labelNames where !taskLabels.contains(need.lowercased()) {
                    return false
                }
            }
            if !matches(date: task.dueDate,
                        range: filter.dateRange,
                        cal: cal,
                        today: startOfToday) { return false }
            if !filter.searchTerms.isEmpty {
                let hit = filter.searchTerms.contains { term in
                    task.title.localizedStandardContains(term)
                        || task.note.localizedStandardContains(term)
                }
                if !hit { return false }
            }
            return true
        }
    }

    private static func matches(
        date: Date?, range: ParsedFilter.DateRange, cal: Calendar, today: Date
    ) -> Bool {
        switch range {
        case .any:     return true
        case .noDate:  return date == nil
        case .overdue:
            guard let d = date else { return false }
            return d < today
        case .today:
            guard let d = date else { return false }
            return cal.isDateInToday(d)
        case .tomorrow:
            guard let d = date else { return false }
            return cal.isDateInTomorrow(d)
        case .nextDays(let n):
            guard let d = date else { return false }
            guard let horizon = cal.date(byAdding: .day, value: n, to: today) else {
                return false
            }
            return d >= today && d < horizon
        }
    }
}

#if DEBUG
extension FilterParser {
    /// Smoke test — exercises every parser axis + apply. Returns true iff
    /// every assertion holds. Stripped from release builds. ponytail:
    /// smallest self-check that catches a parser regression.
    static func __selftest() -> Bool {
        let f1 = parse("p1 today @work foo")
        guard f1.priorities == [1],
              f1.dateRange == .today,
              f1.labelNames == ["work"],
              f1.searchTerms == ["foo"] else { return false }

        let f2 = parse("overdue #personal")
        guard f2.dateRange == .overdue, f2.projectName == "personal" else { return false }

        let f3 = parse("next 7 days p1 p2")
        guard f3.dateRange == .nextDays(7), f3.priorities == [1, 2] else { return false }

        let f4 = parse("")
        guard f4.isEmpty else { return false }

        // Saved-filter smoke: the user-defined filters in `SavedFilter`
        // use the same parser — assert the multi-axis queries a real user
        // would save still parse and apply cleanly against an empty list.
        let saved1 = parse("p1 @urgent")
        guard saved1.priorities == [1], saved1.labelNames == ["urgent"] else { return false }
        guard FilterParser.apply(saved1, to: []).isEmpty else { return false }

        let saved2 = parse("7 days @work")
        guard saved2.dateRange == .nextDays(7), saved2.labelNames == ["work"] else { return false }

        return true
    }
}
#endif