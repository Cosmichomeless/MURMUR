import SwiftUI

/// The app's palette, repeated here because the extension cannot see the app's `Brand`. The three
/// colors live in this target's own asset catalog, copied from the app's.
enum WidgetBrand {
    static let violetDeep = Color("BrandVioletDeep")
    static let violetLight = Color("BrandVioletLight")
    static let coral = Color("BrandCoral")

    static let gradient = LinearGradient(
        colors: [violetDeep, violetLight],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
