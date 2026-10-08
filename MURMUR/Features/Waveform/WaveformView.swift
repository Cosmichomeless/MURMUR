import SwiftUI

/// Draws the live waveform as vertical bars, newest on the right. Like the app icon, the bars are
/// white and fully rounded, and the newest one is the coral accent.
struct WaveformView: View {
    let waveform: LiveWaveform
    var barColor: Color = .white
    var accentColor: Color = Brand.coral
    var barSpacing: CGFloat = 2
    var minimumBarHeight: CGFloat = 2

    var body: some View {
        // Reading `revision` is what subscribes this view (and only this view) to new levels.
        let _ = waveform.revision

        Canvas { context, size in
            let capacity = waveform.capacity
            let slot = size.width / CGFloat(capacity)
            let barWidth = max(slot - barSpacing, 1)
            let count = waveform.count
            let firstSlot = capacity - count // right-align so new levels enter from the right

            for index in 0..<count {
                let level = CGFloat(waveform[index])
                let height = max(level * size.height, minimumBarHeight)
                let rect = CGRect(
                    x: CGFloat(firstSlot + index) * slot + (slot - barWidth) / 2,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                let color = index == count - 1 ? accentColor : barColor
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
