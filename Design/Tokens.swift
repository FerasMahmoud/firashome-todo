import SwiftUI

/// Design tokens — theme-aware. Colors read from ThemeManager so the whole app
/// re-skins (light Todoist-style <-> Dark Glass brand) on toggle.
enum TK {
    private static var tc: ThemeColors {
        ThemeManager.shared.current == .darkGlass ? .darkGlass : .light
    }
    static var isDarkGlass: Bool { ThemeManager.shared.current == .darkGlass }

    // Surfaces
    static var canvas: Color { tc.canvas }
    static var grouped: Color { tc.grouped }
    static var card: Color { tc.card }

    // Text
    static var ink: Color { tc.ink }
    static var secondary: Color { tc.secondary }

    // Lines
    static var hairline: Color { tc.hairline }
    static var hairlineSoft: Color { tc.hairlineSoft }

    // Accent
    static var accent: Color { tc.accent }

    // Completed checkbox fill
    static var completedFill: Color { tc.completedFill }

    // Priority colors — light uses red/orange/blue; dark glass is monochrome (opacity steps)
    static func priority(_ p: Int) -> Color {
        if ThemeManager.shared.current == .darkGlass {
            switch p {
            case 1: return .white
            case 2: return Color(white: 1, opacity: 0.72)
            case 3: return Color(white: 1, opacity: 0.5)
            default: return Color(white: 1, opacity: 0.35)
            }
        }
        switch p {
        case 1: return accent
        case 2: return Color(red: 0.976, green: 0.608, blue: 0.09)
        case 3: return Color(red: 0.251, green: 0.447, blue: 0.831)
        default: return secondary
        }
    }

    // Radii (same in both themes)
    static let rRow: CGFloat = 12
    static let rCard: CGFloat = 16
    static let rPill: CGFloat = 999

    // Typography
    static let title = Font.system(size: 34, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let subhead = Font.system(size: 15, weight: .regular)
    static let sectionHeader = Font.system(size: 13, weight: .medium)
}

// Hide redundant due chip env (unchanged)
private struct HideRedundantDueKey: EnvironmentKey { static let defaultValue: Bool = false }
extension EnvironmentValues {
    var hideRedundantDue: Bool {
        get { self[HideRedundantDueKey.self] }
        set { self[HideRedundantDueKey.self] = newValue }
    }
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
