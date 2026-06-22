import Foundation
import SwiftData

/// A daily habit tracked by the Life OS module. Each tap on the habit's
/// check circle appends today's start-of-day `Date` to `completions`. The
/// streak walks backward day-by-day (schedule-aware: if today isn't done
/// yet, the streak starts from yesterday so it doesn't read 0 before EOD).
@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var cadence: String       // "daily" (only value for now; future: "weekly")
    var target: Int           // completions per day (always 1 for now)
    var timeOfDay: String     // "morning" | "afternoon" | "evening" (routine board)
    var createdAt: Date
    var completions: [Date]   // each entry = startOfDay of a done day

    init(name: String, colorHex: String = "1B8B6A", icon: String = "checkmark.circle", cadence: String = "daily", target: Int = 1, timeOfDay: String = "morning") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.cadence = cadence
        self.target = target
        self.timeOfDay = timeOfDay
        self.createdAt = .now
        self.completions = []
    }

    var isDoneToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return completions.contains { Calendar.current.isDate($0, inSameDayAs: today) }
    }

    /// Schedule-aware streak. Walks backward from today (or yesterday if
    /// today isn't done yet). Returns consecutive completed days.
    var currentStreak: Int {
        let cal = Calendar.current
        var done = Set<Date>()
        for c in completions { done.insert(cal.startOfDay(for: c)) }
        var cursor = cal.startOfDay(for: .now)
        if !done.contains(cursor) { cursor = cal.date(byAdding: .day, value: -1, to: cursor)! }
        var streak = 0
        for _ in 0..<2000 {
            if done.contains(cursor) { streak += 1; cursor = cal.date(byAdding: .day, value: -1, to: cursor)! }
            else { break }
        }
        return streak
    }

    /// Last 7 days (oldest→newest), true if completed.
    var weekStatus: [(date: Date, done: Bool)] {
        let cal = Calendar.current
        var done = Set<Date>()
        for c in completions { done.insert(cal.startOfDay(for: c)) }
        var out: [(Date, Bool)] = []
        var cursor = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now))!
        for _ in 0..<7 {
            out.append((cursor, done.contains(cursor)))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return out
    }

    func toggleToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if let idx = completions.firstIndex(where: { cal.isDate($0, inSameDayAs: today) }) {
            completions.remove(at: idx)
        } else {
            completions.append(today)
        }
    }
}
