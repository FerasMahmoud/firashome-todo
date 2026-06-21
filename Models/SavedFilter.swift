import Foundation
import SwiftData
import SwiftUI

@Model
final class SavedFilter {
    @Attribute(.unique) var id: UUID
    var name: String
    var query: String
    var colorHex: String
    var isFavorite: Bool

    init(name: String, query: String, colorHex: String = "8E8E93", isFavorite: Bool = false) {
        self.id = UUID()
        self.name = name
        self.query = query
        self.colorHex = colorHex
        self.isFavorite = isFavorite
    }

    var color: Color { Color(hex: colorHex) }
}
