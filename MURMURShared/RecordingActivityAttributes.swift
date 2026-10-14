import ActivityKit
import Foundation

/// The Live Activity of a recording in progress. Shared by the app, which drives it, and by the
/// widgets extension, which draws it.
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// While recording, the moment the clock would have read zero. The system counts the time
        /// from it, so the app does not have to update the activity every second. `nil` while paused.
        var clockStart: Date?
        /// What the clock reads, used while paused.
        var elapsed: TimeInterval

        var isPaused: Bool { clockStart == nil }

        static func recording(elapsed: TimeInterval, now: Date = .now) -> ContentState {
            ContentState(clockStart: now.addingTimeInterval(-elapsed), elapsed: elapsed)
        }

        static func paused(elapsed: TimeInterval) -> ContentState {
            ContentState(clockStart: nil, elapsed: elapsed)
        }
    }
}
