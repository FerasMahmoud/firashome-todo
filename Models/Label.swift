import Foundation
import SwiftData
import SwiftUI

@Model
final class Label {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var tasks: [TodoTask] = []

    init(name: String, colorHex: String = "8E8E93") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
    }

    var color: Color { Color(hex: colorHex) }
}
