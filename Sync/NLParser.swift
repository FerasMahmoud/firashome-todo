import Foundation

/// Lightweight natural-language parser for quick-add: pulls out date, priority,
/// project, labels, recurrence, and reminder hints from a free-text task line
/// (Todoist-style). Recognized tokens are stripped from `cleanTitle` so what
/// the user actually typed survives verbatim except for the marker characters.
struct ParsedTask {
    /// Original title with all recognized tokens (`#project`, `@label`,
    /// `p1..p4`, `!30m`, date words, `every X`) removed and trimmed.
    var cleanTitle: String
    var dueDate: Date?
    /// 1 = highest (red) … 4 = none. Matches TodoTask / Todoist semantics.
    var priority: Int = 4
    /// First `#name` token that matches an existing project. Unknown
    /// `#name`s are stripped from the title but never auto-create a project.
    var project: Project? = nil
    /// All `@name` tokens that match existing labels, in source order,
    /// deduped. Unknown `@name`s are stripped but not auto-created.
    var labels: [Label] = []
    /// Wall-clock moment for a local notification (`!30m` / `!1h` / `!2h`).
    /// `nil` = no reminder. Distinct from `dueTime` — reminders live on a
    /// separate `Reminder` model attached to the task.
    var reminderDate: Date? = nil
    /// Simple cadence string (`"daily"` / `"weekly"` / `"monthly"` / `"yearly"`)
    /// matching `RecurrenceKind.storageValue`. Stored on the task as
    /// `recurrenceRule` (the field is also used for free-form RRULE in
    /// other call sites, but the parser only ever produces the simple kind).
    var recurrenceRule: String? = nil
}

enum NLParser {
    /// Parse a free-text title like
    /// `"Call mom tomorrow p1 @urgent #FITech !30m every week"`.
    /// Unknown `#project` / `@label` names are still stripped from the
    /// visible title (so they don't pollute the saved title) but no model is
    /// created. `now` is injectable for unit tests.
    static func parse(
        _ input: String,
        now: Date = Date(),
        projects: [Project] = [],
        labels: [Label] = []
    ) -> ParsedTask {
        let original = input.trimmingCharacters(in: .whitespaces)
        var title = original
        let cal = Calendar.current

        var due: Date? = nil
        var priority = 4
        var recurrenceRule: String? = nil
        var project: Project? = nil
        var matchedLabels: [Label] = []
        var reminderDate: Date? = nil

        // MARK: - Reminder shortcut: !30m / !1h / !2h
        // Anchored to the start of a token. `!` alone is rare in titles so
        // no extra boundary is needed beyond the digit+unit shape.
        // Group 1 = qty, group 2 = unit ("m" or "h").
        if let r = firstRegexMatch(in: title, pattern: #"!(\d+)\s*([mh])\b"#) {
            let qty = Int(r.capture(1) ?? "") ?? 0
            let unit = r.capture(2) ?? "m"
            let seconds = TimeInterval(qty) * (unit == "h" ? 3600 : 60)
            reminderDate = now.addingTimeInterval(seconds)
            title.removeSubrange(r.range)
        }

        // MARK: - @label tokens (resolve against provided labels, dedup)
        // Group 1 = label name.
        let labelHits = allRegexMatches(in: title, pattern: #"@(\w+)"#)
        for hit in labelHits {
            guard let raw = hit.capture(1) else { continue }
            if let lbl = labels.first(where: { $0.name.lowercased() == raw.lowercased() }),
               !matchedLabels.contains(where: { $0.id == lbl.id }) {
                matchedLabels.append(lbl)
            }
        }
        stripFromTitle(&title, ranges: labelHits.map(\.range))

        // MARK: - #project token (first match wins)
        // Group 1 = project name.
        let projectHits = allRegexMatches(in: title, pattern: #"#(\w+)"#)
        if let first = projectHits.first, let raw = first.capture(1) {
            project = projects.first(where: { $0.name.lowercased() == raw.lowercased() })
        }
        stripFromTitle(&title, ranges: projectHits.map(\.range))

        // MARK: - Priority p1..p4 (case-insensitive, first match wins).
        // Word boundary + start-of-string anchor so `p1` doesn't match inside
        // words like `tp1` or `step1`. Captures the digit in group 1.
        for p in 1...4 {
            let pattern = "(?:^|\\s)p\(p)\\b"
            if let r = firstRegexMatch(in: title, pattern: pattern) {
                priority = p
                title.removeSubrange(r.range)
                break
            }
        }

        // MARK: - Recurrence. Most specific patterns first so "every <weekday>"
        // is consumed as recurrence before the bare-day matcher steals it.
        // `every day|week|month|year` wins over the bare `daily|weekly|…` words
        // so we don't strip "daily" before considering "every day" the user
        // actually typed.
        let lower = title.lowercased()
        if lower.contains("every day") {
            recurrenceRule = "daily"
            title = title.replacingOccurrences(of: "every day", with: "", options: .caseInsensitive)
        } else if lower.contains("every week") {
            recurrenceRule = "weekly"
            title = title.replacingOccurrences(of: "every week", with: "", options: .caseInsensitive)
        } else if lower.contains("every month") {
            recurrenceRule = "monthly"
            title = title.replacingOccurrences(of: "every month", with: "", options: .caseInsensitive)
        } else if lower.contains("every year") {
            recurrenceRule = "yearly"
            title = title.replacingOccurrences(of: "every year", with: "", options: .caseInsensitive)
        } else if let r = firstRegexMatch(in: lower, pattern: #"every (sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)\b"#) {
            // "every <weekday>" → weekly. Don't change `due` — the weekday
            // matcher below may set a date if a bare weekday is also present,
            // but the user only gets a date if they explicitly asked for one.
            recurrenceRule = "weekly"
            title.removeSubrange(r.range)
        } else if lower.contains("daily") {
            recurrenceRule = "daily"
            title = title.replacingOccurrences(of: "daily", with: "", options: .caseInsensitive)
        } else if lower.contains("weekly") {
            recurrenceRule = "weekly"
            title = title.replacingOccurrences(of: "weekly", with: "", options: .caseInsensitive)
        } else if lower.contains("monthly") {
            recurrenceRule = "monthly"
            title = title.replacingOccurrences(of: "monthly", with: "", options: .caseInsensitive)
        } else if lower.contains("yearly") {
            recurrenceRule = "yearly"
            title = title.replacingOccurrences(of: "yearly", with: "", options: .caseInsensitive)
        }

        // MARK: - Dates: "today" / "tomorrow" / "next <weekday>" / month-day
        // ("jan 5") / bare weekday. Anchored to the start of a token so
        // "todaybuy" or "atoday" don't match.
        if let r = firstRegexMatch(in: title, pattern: #"(?:^|\s)today\b"#) {
            due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now)
            title.removeSubrange(r.range)
        } else if let r = firstRegexMatch(in: title, pattern: #"(?:^|\s)tomorrow\b"#) {
            let base = cal.date(byAdding: .day, value: 1, to: now) ?? now
            due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base)
            title.removeSubrange(r.range)
        } else if let r = firstRegexMatch(in: title, pattern: #"(?:^|\s)next (sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)\b"#) {
            // "next <weekday>" → that weekday, 1-7 days out (never today).
            // Same delta logic as bare weekday — "next" is just a parser
            // hint that strips the word and keeps the date in the future.
            let name = r.capture(1) ?? ""
            if let target = weekdayIndex(name) {
                let today = cal.component(.weekday, from: now) - 1
                var delta = (target - today + 7) % 7
                if delta == 0 { delta = 7 }
                let base = cal.date(byAdding: .day, value: delta, to: now) ?? now
                due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base)
                title.removeSubrange(r.range)
            }
        } else if let m = firstRegexMatch(in: title, pattern: monthDayPattern) {
            // "jan 5" / "january 5" / "mar 12" → that month/day in the current
            // year, or next year if the date has already passed.
            let monStr = m.capture(1) ?? ""
            let day = Int(m.capture(2) ?? "") ?? 1
            if let month = monthIndex(monStr), let next = nextDate(month: month, day: day, now: now, cal: cal) {
                due = next
                title.removeSubrange(m.range)
            }
        } else if let r = firstRegexMatch(in: title, pattern: #"(?:^|\s)(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)\b"#) {
            let name = r.capture(1) ?? ""
            if let target = weekdayIndex(name) {
                let today = cal.component(.weekday, from: now) - 1
                var delta = (target - today + 7) % 7
                if delta == 0 { delta = 7 } // never "today" — push to next week
                let base = cal.date(byAdding: .day, value: delta, to: now) ?? now
                due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base)
                title.removeSubrange(r.range)
            }
        }

        // Final cleanup: collapse repeated whitespace introduced by token removal.
        let clean = title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return ParsedTask(
            cleanTitle: clean.isEmpty ? original : clean,
            dueDate: due,
            priority: priority,
            project: project,
            labels: matchedLabels,
            reminderDate: reminderDate,
            recurrenceRule: recurrenceRule
        )
    }

    // MARK: - Lookup tables

    private static let weekdayNames = [
        "sunday","monday","tuesday","wednesday","thursday","friday","saturday"
    ]

    /// Ordered: index 0 = January, index 11 = December. Each entry is the
    /// 3-letter abbreviation; the full name is matched via a regex alternation
    /// built from this list + the long forms.
    private static let monthAbbrev: [String] = [
        "jan","feb","mar","apr","may","jun",
        "jul","aug","sep","oct","nov","dec"
    ]

    /// Pattern like `(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|…)`. Matches
    /// "jan", "january", "mar", "march", etc.
    private static let monthDayPattern: String = {
        let alts = monthAbbrev.map { abbrev -> String in
            let long = monthLongName(for: abbrev)
            return "\(abbrev)(?:\(long.dropFirst(3)))?"
        }.joined(separator: "|")
        return "(?:^|\\s)(\(alts))\\s+(\\d{1,2})(?:\\s|$)"
    }()

    private static func monthLongName(for abbrev: String) -> String {
        switch abbrev {
        case "jan": return "january"
        case "feb": return "february"
        case "mar": return "march"
        case "apr": return "april"
        case "may": return "may"
        case "jun": return "june"
        case "jul": return "july"
        case "aug": return "august"
        case "sep": return "september"
        case "oct": return "october"
        case "nov": return "november"
        case "dec": return "december"
        default: return abbrev
        }
    }

    // MARK: - Lookups

    private static func weekdayIndex(_ name: String) -> Int? {
        let n = name.lowercased()
        for (i, full) in weekdayNames.enumerated() {
            if n == full || n == String(full.prefix(3)) { return i }
        }
        return nil
    }

    private static func monthIndex(_ name: String) -> Int? {
        let n = name.lowercased()
        for (i, abbrev) in monthAbbrev.enumerated() {
            if n == abbrev || n == monthLongName(for: abbrev) { return i + 1 }
        }
        return nil
    }

    private static func nextDate(month: Int, day: Int, now: Date, cal: Calendar) -> Date? {
        var comps = cal.dateComponents([.year], from: now)
        comps.month = month
        comps.day = day
        comps.hour = 9
        comps.minute = 0
        guard let candidate = cal.date(from: comps) else { return nil }
        // If the day is already past in the current year, roll into next year.
        if candidate < cal.startOfDay(for: now) {
            comps.year = (comps.year ?? cal.component(.year, from: now)) + 1
            return cal.date(from: comps)
        }
        return candidate
    }

    // MARK: - Tiny regex wrapper

    private struct RegexMatch {
        let range: Range<String.Index>
        /// Capture groups. `captures[0]` = full match, `captures[1+]` = groups
        /// from the regex. Returns `nil` for groups that didn't participate.
        private let captures: [String?]

        init(range: Range<String.Index>, captures: [String?]) {
            self.range = range
            self.captures = captures
        }

        /// Capture group at `index` (0 = full match, 1+ = explicit groups).
        func capture(_ index: Int) -> String? {
            guard index >= 0, index < captures.count else { return nil }
            return captures[index]
        }
    }

    private static func firstRegexMatch(in haystack: String, pattern: String) -> RegexMatch? {
        allRegexMatches(in: haystack, pattern: pattern).first
    }

    private static func allRegexMatches(in haystack: String, pattern: String) -> [RegexMatch] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let ns = haystack as NSString
        let matches = re.matches(in: haystack, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m in
            guard let swiftRange = Range(m.range, in: haystack) else { return nil }
            var caps: [String?] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                if r.location == NSNotFound {
                    caps.append(nil)
                } else if let srange = Range(r, in: haystack) {
                    caps.append(String(haystack[srange]))
                } else {
                    caps.append(nil)
                }
            }
            return RegexMatch(range: swiftRange, captures: caps)
        }
    }

    /// Remove each range from `title`. Removes in reverse order so each
    /// removal doesn't shift the indices of the ranges that come before it.
    private static func stripFromTitle(_ title: inout String, ranges: [Range<String.Index>]) {
        for r in ranges.reversed() {
            title.removeSubrange(r)
        }
    }
}
