import Foundation
import SwiftData
import SwiftUI

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var order: Int
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade, inverse: \TodoTask.project)
    var tasks: [TodoTask] = []

    @Relationship(deleteRule: .cascade, inverse: \TaskSection.project)
    var sections: [TaskSection] = []

    init(name: String, colorHex: String = "8E8E93", order: Int = 0, isFavorite: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.order = order
        self.isFavorite = isFavorite
    }

    var color: Color { Color(hex: colorHex) }
}
