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
        Color(red: 0.15, green: 0.17, blue: 0.22)
    }
}
