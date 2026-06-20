import SwiftUI

/// iOS 26 Liquid Glass, with a graceful blur fallback for older OS.
extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 18) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Translucent floating bar (nav / bottom add bar) — glass on iOS 26, material elsewhere.
    @ViewBuilder
    func glassBar() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: 0, style: .continuous))
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
