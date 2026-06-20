import SwiftUI
import UIKit

enum PlanetBg {
    static func image() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "planet", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

/// Planet image layer (visible but dimmed for readability).
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

/// Glass background: planet + dark scrim (no Material — uses gradient to simulate frost).
struct GlassPlanetBg: View {
    var body: some View {
        if TK.isDarkGlass {
            PlanetLayer()
        } else {
            TK.canvas
        }
    }
}

/// Row background: simulated frosted glass via subtle white gradient.
/// Visible as a translucent glass card over the planet.
struct GlassRowBg: View {
    var body: some View {
        if TK.isDarkGlass {
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            TK.canvas
        }
    }
}

/// Frosted glass background: planet + ultraThinMaterial (real blur, same as Quick Add sheet).
/// This is what makes it look GLASSY — the material blurs the planet behind it.
struct FrostedGlassBg: View {
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

/// Glass row background: visible translucent gradient card (simulates frosted glass).
struct GlassRowBg: View {
    var body: some View {
        if TK.isDarkGlass {
            LinearGradient(
                colors: [Color.white.opacity(0.09), Color.white.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            TK.canvas
        }
    }
}
