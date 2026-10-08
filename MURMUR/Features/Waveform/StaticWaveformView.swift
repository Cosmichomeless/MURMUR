import SwiftUI

/// A finished recording's waveform as vertical bars. The part already played is white, what is left
/// is dimmed, and the bar at the playback position is the icon's coral accent.
struct StaticWaveformView: View {
    let levels: [Float]
    var playedColor: Color = .white
    var remainingColor: Color = Brand.dimmedBar
    var accentColor: Color = Brand.coral
    /// 0...1
    var progress: Double = 0
    var barSpacing: CGFloat = 2
    var minimumBarHeight: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            guard !levels.isEmpty else { return }
            let slot = size.width / CGFloat(levels.count)
            let barWidth = max(slot - barSpacing, 1)
            let playedBars = Int((progress * Double(levels.count)).rounded(.down))
            let playhead = min(playedBars, levels.count - 1)

            for (index, level) in levels.enumerated() {
                let height = max(CGFloat(level) * size.height, minimumBarHeight)
                let rect = CGRect(
                    x: CGFloat(index) * slot + (slot - barWidth) / 2,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                let color: Color = index == playhead ? accentColor : (index < playedBars ? playedColor : remainingColor)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
