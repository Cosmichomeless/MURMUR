import AVFoundation

enum AudioPlayerError: Error, Equatable, LocalizedError {
    case cannotLoad(String)
    case nothingLoaded
    case cannotPlay

    var errorDescription: String? {
        switch self {
        case .cannotLoad(let reason):
            "The recording could not be opened: \(reason)"
        case .nothingLoaded:
            "There is no recording loaded."
        case .cannotPlay:
            "The recording could not be played."
        }
    }
}

/// Plays one saved recording with `AVAudioPlayer`.
///
/// `AVAudioPlayer` fits playback of a local file: it seeks, reports its own position and tells us when
/// it reaches the end. The engine-based pipeline is only needed for capture, where we tap the input.
/// The session is not touched here: whoever starts playback activates it (see `PlayerViewModel`).
@MainActor
final class AudioPlayer: NSObject, AudioPlaying {
    private(set) var state: PlayerState = .idle
    private(set) var duration: TimeInterval = 0
    private var player: AVAudioPlayer?

    /// The end of the audio counts as the position once finished: `AVAudioPlayer` may rewind itself.
    var currentTime: TimeInterval {
        state == .finished ? duration : (player?.currentTime ?? 0)
    }

    func load(url: URL) throws {
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.prepareToPlay() else { throw AudioPlayerError.cannotLoad("unsupported audio") }
            self.player = player
            duration = player.duration
            state = .paused
        } catch let error as AudioPlayerError {
            throw error
        } catch {
            throw AudioPlayerError.cannotLoad(error.localizedDescription)
        }
    }

    func play() throws {
        guard let player else { throw AudioPlayerError.nothingLoaded }
        if state == .finished { player.currentTime = 0 }
        guard player.play() else { throw AudioPlayerError.cannotPlay }
        state = .playing
    }

    func pause() {
        guard state == .playing else { return }
        player?.pause()
        state = .paused
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(time, 0), duration)
        // Moving away from the end makes the recording playable from there again.
        if state == .finished { state = .paused }
    }

    func stop() {
        player?.stop()
        player = nil
        duration = 0
        state = .idle
    }

    fileprivate func playbackFinished() {
        guard state == .playing else { return }
        state = .finished
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    // Called on an arbitrary thread; hop to the main actor without sending the (non-Sendable) player.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.playbackFinished()
        }
    }
}
