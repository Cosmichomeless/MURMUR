import SwiftUI

/// A round control like the icon's bars: a filled circle with a soft shadow and one glyph.
struct BrandRoundButtonStyle: ButtonStyle {
    enum Kind {
        /// The coral accent with a deep-violet glyph (white on coral is under 3:1): the main action.
        case accent
        /// White with a violet glyph: a secondary action.
        case light
        /// Translucent white: a quiet or destructive action.
        case quiet
    }

    var kind: Kind
    /// Diameter at the default text size; it scales with Dynamic Type.
    var size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        RoundButton(configuration: configuration, kind: kind, size: size)
    }

    private struct RoundButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @ScaledMetric private var diameter: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        init(configuration: ButtonStyleConfiguration, kind: Kind, size: CGFloat) {
            self.configuration = configuration
            self.kind = kind
            _diameter = ScaledMetric(wrappedValue: size, relativeTo: .title)
        }

        var body: some View {
            configuration.label
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(fill))
                .shadow(color: Brand.Shadow.color, radius: Brand.Shadow.radius, y: Brand.Shadow.offset)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .opacity(isEnabled ? 1 : 0.5)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(Circle())
        }

        private var fill: Color {
            switch kind {
            case .accent: Brand.coral
            case .light: .white
            case .quiet: .white.opacity(0.18)
            }
        }

        private var glyph: Color {
            switch kind {
            case .quiet: .white
            case .accent, .light: Brand.violetDeep
            }
        }
    }
}

/// A text button for use on the gradient: a white capsule with violet text (13:1).
struct BrandPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Brand.violetDeep)
            .padding(.horizontal, Brand.Spacing.large)
            .padding(.vertical, Brand.Spacing.small + 4)
            .background(Capsule().fill(.white))
            .shadow(color: Brand.Shadow.color, radius: Brand.Shadow.radius, y: Brand.Shadow.offset)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}
