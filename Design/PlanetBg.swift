import SwiftUI
import UIKit

enum PlanetBg {
    static func image() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "planet", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

struct PlanetLayer: View {
    var body: some View {
        if let img = PlanetBg.image() {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .brightness(-0.18)
                .overlay(Color.black.opacity(0.35))
                .ignoresSafeArea()
        }
    }
}

/// Glass row background: visible translucent gradient (simulates frosted glass cards).
struct GlassRowBg: View {
    var body: some View {
        if TK.isDarkGlass {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.09)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        } else {
            TK.canvas
        }
    }
}
