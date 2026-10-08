import SwiftUI

/// The visual language of the app icon, in one place: a violet gradient, white rounded bars and a
/// single coral accent. Colors live in the asset catalog (with light and dark variants where it
/// matters); everything else a screen needs to look like the icon is here.
enum Brand {
    // MARK: Color

    /// Icon gradient, top right.
    static let violetDeep = Color("BrandVioletDeep")
    /// Icon gradient, bottom left.
    static let violetLight = Color("BrandVioletLight")
    /// The icon's central accent bar.
    static let coral = Color("BrandCoral")

    /// Text and glyphs on the gradient. White on the lightest violet is 5.9:1.
    static let onGradient = Color.white
    /// Secondary text on the gradient; kept opaque enough for 4.5:1 against `violetLight`.
    static let onGradientSecondary = Color.white.opacity(0.85)
    /// Waveform bars that are not "now" (not yet played).
    static let dimmedBar = Color.white.opacity(0.4)

    static let gradient = LinearGradient(
        colors: [violetDeep, violetLight],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    // MARK: Shape and space

    enum Radius {
        static let tile: CGFloat = 10
        static let card: CGFloat = 16
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    enum Shadow {
        static let color = Color.black.opacity(0.25)
        static let radius: CGFloat = 8
        static let offset: CGFloat = 4
    }
}

/// The icon's background, edge to edge.
struct BrandBackground: View {
    var body: some View {
        Brand.gradient.ignoresSafeArea()
    }
}

extension View {
    /// Puts the screen on the icon's gradient with light content. The gradient is dark in light mode
    /// too, so adaptive colors (the coral accent) resolve to their dark variant here.
    func brandScreen() -> some View {
        foregroundStyle(Brand.onGradient)
            .tint(Brand.onGradient)
            .environment(\.colorScheme, .dark)
            .background { BrandBackground() }
    }
}
