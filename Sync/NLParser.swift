import Foundation

/// Lightweight natural-language parser for quick-add: pulls out date, priority,
/// and label hints from a free-text task line (Todoist-style).
struct ParsedTask {
    var cleanTitle: String
    var dueDate: Date?
    var priority: Int = 4
}

enum NLParser {
    /// Parse "Call mom tomorrow p1" -> ParsedTask(title:"Call mom", due:tomorrow, priority:1).
    static func parse(_ input: String) -> ParsedTask {
        var title = input.trimmingCharacters(in: .whitespaces)
        var due: Date? = nil
        var priority = 4

        let cal = Calendar.current
        let lower = title.lowercased()

        // Priority: p1/p2/p3
        for p in 1...3 {
            let token = " p\(p)"
            if lower.contains(token) {
                priority = p
                title = title.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
                break
            }
        }

        // Dates
        if lower.contains(" today") {
            due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
            title = title.replacingOccurrences(of: " today", with: "", options: .caseInsensitive)
        } else if lower.contains(" tomorrow") {
            due = cal.date(byAdding: .day, value: 1, to: Date())
            title = title.replacingOccurrences(of: " tomorrow", with: "", options: .caseInsensitive)
        } else {
            for (i, day) in ["sunday","monday","tuesday","wednesday","thursday","friday","saturday"].enumerated() {
                let short = String(day.prefix(3))
                if lower.contains(" \(day)") || lower.contains(" \(short)") {
                    let today = (cal.component(.weekday, from: Date()) - 1)
                    var delta = (i - today + 7) % 7
                    if delta == 0 { delta = 7 }
                    due = cal.date(byAdding: .day, value: delta, to: Date())
                    title = title.replacingOccurrences(of: " \(day)", with: "", options: .caseInsensitive)
                        .replacingOccurrences(of: " \(short)", with: "", options: .caseInsensitive)
                    break
                }
            }
        }

        // Strip trailing @label / #project hints from the visible title (kept simple).
        title = title.trimmingCharacters(in: .whitespaces)
        return ParsedTask(cleanTitle: title.isEmpty ? input.trimmingCharacters(in: .whitespaces) : title,
                          dueDate: due, priority: priority)
    }
}
