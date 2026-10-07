import Foundation

/// What the system tells us about the audio session, reduced to what MURMUR reacts to.
enum AudioSessionEvent: Sendable, Equatable {
    /// A call, Siri, an alarm… took over audio. The system has already stopped our I/O.
    case interruptionBegan
    /// The interruption is over. `shouldResume` is the system's hint that resuming is appropriate.
    case interruptionEnded(shouldResume: Bool)
    /// The device in use went away, e.g. headphones were unplugged.
    case routeLost
    /// `mediaserverd` restarted: every audio object we hold is invalid.
    case mediaServicesReset
}

/// Boundary around the session notifications, so view models can be tested without `AVAudioSession`.
///
/// Every call returns an independent stream: recorder and player both listen.
@MainActor
protocol AudioSessionEventSource: AnyObject {
    func subscribe() -> AsyncStream<AudioSessionEvent>
}
