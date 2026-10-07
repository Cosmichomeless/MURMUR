import SwiftUI

/// A finished recording's waveform as vertical bars; the part already played is highlighted.
struct StaticWaveformView: View {
    let levels: [Float]
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

            for (index, level) in levels.enumerated() {
                let height = max(CGFloat(level) * size.height, minimumBarHeight)
                let rect = CGRect(
                    x: CGFloat(index) * slot + (slot - barWidth) / 2,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                let color: Color = index < playedBars ? .accentColor : .secondary.opacity(0.4)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
