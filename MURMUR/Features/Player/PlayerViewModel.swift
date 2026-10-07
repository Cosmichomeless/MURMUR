import Foundation
import Observation

/// Drives playback of one recording at a time: loading, the session, and the progress shown on screen.
@MainActor
@Observable
final class PlayerViewModel {
    private(set) var state: PlayerState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// The last failure to load or play, shown instead of the controls' effect.
    private(set) var errorMessage: String?

    @ObservationIgnored private let player: any AudioPlaying
    @ObservationIgnored private let session: any AudioSessionControlling
    @ObservationIgnored private var ticker: Task<Void, Never>?

    /// How often the position is read while playing. 20 Hz keeps the slider smooth and cheap.
    private static let tickInterval = Duration.milliseconds(50)

    init(player: any AudioPlaying, session: any AudioSessionControlling) {
        self.player = player
        self.session = session
    }

    var isPlaying: Bool { state == .playing }
    var isLoaded: Bool { state != .idle }

    /// 0...1, for drawing progress over the waveform.
    var progress: Double {
        duration > 0 ? min(max(currentTime / duration, 0), 1) : 0
    }

    /// Loads a recording ready at its start, replacing whatever was loaded.
    func load(url: URL) {
        release()
        errorMessage = nil
        do {
            try player.load(url: url)
            sync()
            duration = player.duration
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayPause() {
        switch state {
        case .playing: pause()
        case .paused, .finished: play()
        case .idle: break
        }
    }

    func play() {
        guard isLoaded else { return }
        errorMessage = nil
        do {
            try session.activateForPlayback()
            try player.play()
            sync()
            startTicking()
        } catch {
            session.deactivate()
            errorMessage = error.localizedDescription
            sync()
        }
    }

    /// The session stays active so resuming is instant; it is released by `stop()` or at the end.
    func pause() {
        player.pause()
        stopTicking()
        sync()
    }

    func seek(to time: TimeInterval) {
        guard isLoaded else { return }
        player.seek(to: time)
        sync()
    }

    /// Unloads the recording and gives the audio session back.
    func stop() {
        release()
        errorMessage = nil
    }

    /// One poll of the player. Internal so tests can drive it without waiting.
    func tick() {
        sync()
        guard state != .playing else { return }
        stopTicking()
        // Reached the end on its own: nothing is playing, so other apps may resume.
        session.deactivate()
    }

    // MARK: - Private

    private func sync() {
        state = player.state
        currentTime = player.currentTime
    }

    private func release() {
        stopTicking()
        let wasLoaded = isLoaded
        player.stop()
        if wasLoaded { session.deactivate() }
        state = .idle
        currentTime = 0
        duration = 0
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                guard !Task.isCancelled, let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }
}
