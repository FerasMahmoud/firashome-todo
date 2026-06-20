import SwiftUI

/// Design tokens — light Todoist-style theme. Restrained, one accent.
/// Per brand rule [[feedback_premium_apple_simple]]: minimal color, one type system.
enum TK {
    // Surfaces
    static let canvas = Color.white
    static let grouped = Color(red: 0.949, green: 0.949, blue: 0.969)   // #F2F2F7 systemGroupedBackground
    static let card = Color.white

    // Text
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.102)       // #1A1A1A
    static let secondary = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93

    // Lines
    static let hairline = Color(red: 0.855, green: 0.855, blue: 0.878)
    static let hairlineSoft = Color(white: 0.92)

    // Accent (single) — Todoist red
    static let accent = Color(red: 0.898, green: 0.224, blue: 0.208)    // #E53935

    // Priority colors
    static func priority(_ p: Int) -> Color {
        switch p {
        case 1: return accent
        case 2: return Color(red: 0.976, green: 0.608, blue: 0.09)     // orange
        case 3: return Color(red: 0.251, green: 0.447, blue: 0.831)    // blue
        default: return secondary
        }
    }

    // Radii
    static let rRow: CGFloat = 12
    static let rCard: CGFloat = 16
    static let rPill: CGFloat = 999

    // Typography helpers
    static let title = Font.system(size: 34, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let subhead = Font.system(size: 15, weight: .regular)
    static let sectionHeader = Font.system(size: 13, weight: .medium)
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r, g, b, a: Double
        switch h.count {
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
