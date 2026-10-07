import Foundation

enum DurationFormat {
    /// `m:ss`, or `h:mm:ss` from one hour. Rounds down so the label never runs ahead of the audio.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
