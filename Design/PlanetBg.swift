import SwiftUI
import UIKit

/// Loads the bundled planet image for the dark-glass background.
enum PlanetBg {
    static func image() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "planet", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

/// A view showing the dimmed planet as a background layer.
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
