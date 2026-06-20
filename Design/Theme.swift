import SwiftUI

enum AppTheme: String, CaseIterable {
    case light, darkGlass
    var label: String { self == .darkGlass ? "Dark Glass" : "Light" }
}

/// Global theme state. Root view observes it so toggling re-renders the whole tree.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var raw: String {
        didSet { UserDefaults.standard.set(raw, forKey: "appTheme") }
    }
    init() { raw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.light.rawValue }
    var current: AppTheme { AppTheme(rawValue: raw) ?? .light }
}

/// Per-theme color set. Dark Glass = strict monochrome (brand.firashome.uk).
struct ThemeColors {
    let canvas: Color
    let grouped: Color
    let card: Color
    let ink: Color
    let secondary: Color
    let hairline: Color
    let hairlineSoft: Color
    let accent: Color
    let completedFill: Color

    static let light = ThemeColors(
        canvas: .white,
        grouped: Color(red: 0.949, green: 0.949, blue: 0.969),
        card: .white,
        ink: Color(red: 0.102, green: 0.102, blue: 0.102),
        secondary: Color(red: 0.557, green: 0.557, blue: 0.576),
        hairline: Color(red: 0.855, green: 0.855, blue: 0.878),
        hairlineSoft: Color(white: 0.92),
        accent: Color(red: 0.863, green: 0.298, blue: 0.306),
        completedFill: Color(red: 0.83, green: 0.84, blue: 0.86))

    /// Dark Glass: translucent white glass panels over a visible planet (brand.firashome.uk).
    static let darkGlass = ThemeColors(
        canvas: Color(white: 1, opacity: 0.05),       // brand surface-1: faint frosted glass
        grouped: Color.clear,
        card: Color(white: 1, opacity: 0.08),          // brand surface-2: glass panels
        ink: .white,
        secondary: Color(white: 1, opacity: 0.85),
        hairline: Color(white: 1, opacity: 0.12),
        hairlineSoft: Color(white: 1, opacity: 0.07),
        accent: .white,
        completedFill: Color(white: 1, opacity: 0.3))
}
