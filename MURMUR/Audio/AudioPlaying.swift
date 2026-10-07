import Foundation

enum PlayerState: Sendable, Equatable {
    /// Nothing loaded.
    case idle
    /// Loaded and not playing (initial position, or after an explicit pause).
    case paused
    case playing
    /// Reached the end of the audio. `play()` restarts from the beginning.
    case finished
}

/// Boundary around audio playback.
///
/// Like the recorder, the player is independent of persistence: it plays a file URL.
@MainActor
protocol AudioPlaying: AnyObject {
    var state: PlayerState { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    func load(url: URL) throws
    func play() throws
    func pause()
    func seek(to time: TimeInterval)
    func stop()
}
