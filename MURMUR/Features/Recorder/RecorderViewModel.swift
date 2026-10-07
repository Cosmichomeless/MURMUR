import Foundation
import Observation

/// Owns the recording state machine and the elapsed time shown while recording.
@MainActor
@Observable
final class RecorderViewModel {
    private(set) var state: RecorderState = .idle
    private(set) var elapsed: TimeInterval = 0
    /// Increments each time a recording is saved by `stop()`; views observe it to close the recorder.
    private(set) var savedCount = 0
    /// A non-blocking message, e.g. when a failure still left a usable recording.
    private(set) var notice: String?

    /// Separate observable: only the waveform view redraws at the sample rate.
    @ObservationIgnored let waveform: LiveWaveform
    @ObservationIgnored private let access: MicrophoneAccess
    @ObservationIgnored private let recorder: any AudioRecording
    @ObservationIgnored private let save: (RecordedAudio) throws -> Void
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var eventObserver: Task<Void, Never>?

    /// - Parameters:
    ///   - events: Session interruptions and route changes. Without it the recorder ignores them.
    ///   - save: Takes ownership of a finished recording (moves the temporary file somewhere permanent).
    init(
        access: MicrophoneAccess,
        recorder: any AudioRecording,
        waveform: LiveWaveform = LiveWaveform(),
        events: (any AudioSessionEventSource)? = nil,
        save: @escaping (RecordedAudio) throws -> Void
    ) {
        self.waveform = waveform
        self.access = access
        self.recorder = recorder
        self.save = save
        if let events { observe(events) }
    }

    func start() async {
        guard state == .idle || isFailed else { return }
        guard await access.prepareForRecording() else { return }
        // The permission prompt suspends: another start may have won in the meantime.
        guard state == .idle || isFailed, let next = state.applying(.start) else { return }

        do {
            let samples = try recorder.start()
            state = next
            elapsed = 0
            waveform.reset()
            notice = nil
            consume(samples)
        } catch {
            access.releaseSession()
            state = .failed(error.localizedDescription)
        }
    }

    func pause() {
        guard let next = state.applying(.pause) else { return }
        recorder.pause()
        state = next
    }

    func resume() {
        guard let next = state.applying(.resume) else { return }
        do {
            // The session may have been taken away while paused (interruption, another app).
            try access.reactivate()
            try recorder.resume()
            state = next
            notice = nil
        } catch {
            keepCapturedAudio(because: error.localizedDescription)
        }
    }

    /// Call when the app returns to the foreground. The user may have withdrawn the microphone
    /// permission in Settings while a recording was open.
    func permissionDidChange() {
        guard state.isCapturing else { return }
        access.refresh()
        guard access.permission != .granted else { return }
        keepCapturedAudio(because: "microphone access was turned off")
    }

    /// Stops and saves the recording.
    func stop() {
        guard let next = state.applying(.stop) else { return }
        stopConsuming()
        defer { access.releaseSession() }
        do {
            let audio = try recorder.stop()
            try save(audio)
            state = next
            elapsed = 0
            savedCount += 1
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Throws the recording away, including its temporary file.
    func discard() {
        guard let next = state.applying(.discard) else { return }
        stopConsuming()
        recorder.discard()
        access.releaseSession()
        state = next
        elapsed = 0
    }

    func dismissFailure() {
        guard let next = state.applying(.dismissFailure) else { return }
        state = next
        elapsed = 0
    }

    // MARK: - Private

    private var isFailed: Bool {
        if case .failed = state { true } else { false }
    }

    private func consume(_ samples: AsyncThrowingStream<RecorderSample, Error>) {
        consumer = Task { [weak self] in
            do {
                for try await sample in samples {
                    self?.apply(sample)
                }
            } catch {
                self?.keepCapturedAudio(because: error.localizedDescription)
            }
        }
    }

    private func observe(_ events: any AudioSessionEventSource) {
        let stream = events.subscribe()
        eventObserver = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: AudioSessionEvent) {
        switch event {
        case .interruptionBegan:
            pauseForInterruption()
        case .mediaServicesReset:
            keepCapturedAudio(because: "audio services were reset")
        case .interruptionEnded, .routeLost:
            // Resuming a microphone on its own would be a surprise, so the user taps resume.
            // An input lost mid-capture is reported by the recorder as a configuration change.
            break
        }
    }

    /// A call or another app took the audio. Pause rather than stop: the user decides what's next.
    private func pauseForInterruption() {
        guard state == .recording, let next = state.applying(.pause) else { return }
        recorder.pause()
        state = next
        notice = "Paused because another app took the microphone. Tap resume to continue."
    }

    private func apply(_ sample: RecorderSample) {
        waveform.append(sample.level)
        // Only publish when the displayed tenth of a second changes: fewer view updates.
        guard Int(sample.duration * 10) != Int(elapsed * 10) else { return }
        elapsed = sample.duration
    }

    /// The capture broke (disk full, input lost, permission withdrawn…). Keep whatever was written
    /// before it: a long recording is worth more than a clean failure.
    private func keepCapturedAudio(because reason: String) {
        guard state.isCapturing else { return }
        stopConsuming()
        defer { access.releaseSession() }
        do {
            let audio = try recorder.stop()
            try save(audio)
            state = .idle
            elapsed = 0
            notice = "Recording stopped early (\(reason)). What was captured has been saved."
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func stopConsuming() {
        consumer?.cancel()
        consumer = nil
    }
}
