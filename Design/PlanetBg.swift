import SwiftUI
import UIKit

enum PlanetBg {
    static func image() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "planet", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

/// Planet image layer (dimmed).
struct PlanetLayer: View {
    var body: some View {
        if let img = PlanetBg.image() {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .brightness(-0.12)
                .overlay(Color.black.opacity(0.22))
                .ignoresSafeArea()
        }
    }
}

/// FROSTED GLASS background: planet + ultraThinMaterial (real blur, not flat tint).
/// This is the actual glassmorphism — the material blurs the planet behind it.
struct GlassPlanetBg: View {
    var body: some View {
        if TK.isDarkGlass {
            ZStack {
                PlanetLayer()
                Rectangle().fill(.ultraThinMaterial)
            }
        } else {
            TK.canvas
        }
    }
}

/// Row background: frosted glass (thinMaterial) in dark glass, solid canvas in light.
struct GlassRowBg: View {
    var body: some View {
        if TK.isDarkGlass {
            Rectangle().fill(.thinMaterial)
        } else {
            TK.canvas
        }
    }
}
