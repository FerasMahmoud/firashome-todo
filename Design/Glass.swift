import SwiftUI

/// Translucent glass-like backgrounds. iOS 26's `.glassEffect` symbol is absent
/// on the Xcode 16 (iOS 18) SDK used in CI, so we ship the material fallback
/// unconditionally. Re-enable `.glassEffect` under a `#if compiler(>=6.2)` /
/// iOS-26-SDK guard once CI runs Xcode 26.
extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 18) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Translucent floating bar (nav / bottom add bar).
    @ViewBuilder
    func glassBar() -> some View {
        self.background(.ultraThinMaterial)
    }
}
