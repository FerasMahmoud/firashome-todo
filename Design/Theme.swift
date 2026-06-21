import SwiftUI

enum AppTheme: String, CaseIterable {
    case light, darkGlass, sepia
    var label: String {
        switch self {
        case .light:     return "Light"
        case .darkGlass: return "Dark Glass"
        case .sepia:     return "Sepia"
        }
    }
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

    /// Resolve the palette for a given theme in one place. Add a new arm
    /// here whenever `AppTheme` grows a case so call sites stay terse.
    static func palette(for theme: AppTheme) -> ThemeColors {
        switch theme {
        case .light:     return .light
        case .darkGlass: return .darkGlass
        case .sepia:     return .sepia
        }
    }

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

    /// Sepia (Tier-2 #36): warm cream paper + brown ink + rust accent.
    /// Designed for long reading sessions — the soft cream canvas avoids
    /// the harshness of pure white, the rust accent keeps the palette warm
    /// instead of sliding into the purple-on-cream AI-slop direction.
    /// Every token matches the surface that `light` and `darkGlass` expose,
    /// so any view already bound to `ThemeColors` works without changes.
    /// ponytail: `TK.swift` still hardcodes a `darkGlass` branch and falls
    /// back to `light` for everything else, so `sepia` is reachable via
    /// `ThemeColors.sepia` / `ThemeColors.palette(for: .sepia)` until that
    /// file grows a third arm. Upgrade = extend `TK.tc` to switch on
    /// `ThemeManager.shared.current` and keep this palette in sync.
    static let sepia = ThemeColors(
        canvas:        Color(red: 0.961, green: 0.937, blue: 0.878),  // warm cream
        grouped:       Color(red: 0.922, green: 0.890, blue: 0.816),  // deeper cream
        card:          Color(red: 0.961, green: 0.937, blue: 0.878),  // matches canvas
        ink:           Color(red: 0.243, green: 0.173, blue: 0.110),  // dark sepia ink
        secondary:     Color(red: 0.478, green: 0.416, blue: 0.333),  // medium brown
        hairline:      Color(red: 0.851, green: 0.804, blue: 0.690),  // warm tan
        hairlineSoft:  Color(red: 0.902, green: 0.867, blue: 0.776),  // softer tan
        accent:        Color(red: 0.722, green: 0.361, blue: 0.173),  // rust sienna
        completedFill: Color(red: 0.792, green: 0.745, blue: 0.643))  // muted tan
}
