import Foundation
import SwiftData

/// A countdown to a future (or past) date — Life OS module. Each entry
/// shows a big "days to go" number and a progress ring that fills as the
/// event approaches. Sorted by `targetDate` (soonest first).
@Model
final class CountdownEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetDate: Date
    var colorHex: String
    var icon: String

    init(title: String, targetDate: Date, colorHex: String = "DC4C4E", icon: String = "flag.fill") {
        self.id = UUID()
        self.title = title
        self.targetDate = targetDate
        self.colorHex = colorHex
        self.icon = icon
    }

    /// Whole days until (or since) the target. Negative = past.
    var daysUntil: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isPast: Bool { daysUntil < 0 }
}
