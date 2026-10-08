import SwiftUI
import Testing
import UIKit
@testable import MURMUR

/// The brand palette must stay readable: these resolve the real asset-catalog colors and apply the
/// WCAG 2 contrast formula, so a color tweak that breaks AA fails here.
struct BrandContrastTests {
    private struct RGB {
        let red: Double, green: Double, blue: Double

        /// Composites `self` at `opacity` over `background`.
        func over(_ background: RGB, opacity: Double) -> RGB {
            RGB(
                red: red * opacity + background.red * (1 - opacity),
                green: green * opacity + background.green * (1 - opacity),
                blue: blue * opacity + background.blue * (1 - opacity)
            )
        }

        var luminance: Double {
            func linear(_ value: Double) -> Double {
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        func contrast(with other: RGB) -> Double {
            let (light, dark) = (max(luminance, other.luminance), min(luminance, other.luminance))
            return (light + 0.05) / (dark + 0.05)
        }
    }

    private static let white = RGB(red: 1, green: 1, blue: 1)
    private static let black = RGB(red: 0, green: 0, blue: 0)

    private func catalogColor(_ name: String, dark: Bool = false) throws -> RGB {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: traits), "\(name) is missing")
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        #expect(color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return RGB(red: red, green: green, blue: blue)
    }

    @Test func everyBrandColorExistsInTheCatalog() throws {
        for name in ["AccentColor", "BrandCoral", "BrandVioletDeep", "BrandVioletLight"] {
            _ = try catalogColor(name)
            _ = try catalogColor(name, dark: true)
        }
    }

    @Test func whiteTextIsReadableOnBothEndsOfTheGradient() throws {
        for name in ["BrandVioletDeep", "BrandVioletLight"] {
            let background = try catalogColor(name)
            #expect(Self.white.contrast(with: background) >= 4.5, "white on \(name)")
            // Secondary text is white at 85%.
            let secondary = Self.white.over(background, opacity: 0.85)
            #expect(secondary.contrast(with: background) >= 4.5, "secondary on \(name)")
        }
    }

    @Test func theAccentColorIsReadableAsTextOnTheSystemBackgrounds() throws {
        #expect(try catalogColor("AccentColor").contrast(with: Self.white) >= 4.5, "light mode")
        #expect(try catalogColor("AccentColor", dark: true).contrast(with: Self.black) >= 4.5, "dark mode")
    }

    @Test func theCoralAccentStandsOutAsGraphicsWhereTheWaveformIsDrawn() throws {
        // Screens on the gradient are always dark, so they use the dark variant. The waveform sits in
        // the middle of the screen: between the deep end and the halfway blend (the lightest corner
        // only ever holds the decorative bottom edge).
        let coral = try catalogColor("BrandCoral", dark: true)
        let deep = try catalogColor("BrandVioletDeep")
        let halfway = try catalogColor("BrandVioletLight").over(deep, opacity: 0.5)
        #expect(coral.contrast(with: deep) >= 3, "coral on the deep end")
        #expect(coral.contrast(with: halfway) >= 3, "coral on the halfway blend")
    }

    @Test func theVioletTextOnWhitePillButtonsIsReadable() throws {
        #expect(try catalogColor("BrandVioletDeep").contrast(with: Self.white) >= 4.5)
    }

    @Test func deepVioletGlyphsOnTheCoralButtonAreReadable() throws {
        // White on coral is under 3:1 in dark mode, so the accent button carries a deep-violet glyph.
        let glyph = try catalogColor("BrandVioletDeep")
        #expect(glyph.contrast(with: try catalogColor("BrandCoral")) >= 3, "light mode")
        #expect(glyph.contrast(with: try catalogColor("BrandCoral", dark: true)) >= 4.5, "dark mode")
    }
}
