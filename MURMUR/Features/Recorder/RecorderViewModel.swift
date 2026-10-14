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
    /// How long the last recording took from the request to start until its first audio, once it came.
    private(set) var startLatency: Duration?

    /// Separate observable: only the waveform view redraws at the sample rate.
    @ObservationIgnored let waveform: LiveWaveform
    @ObservationIgnored private let access: MicrophoneAccess
    @ObservationIgnored private let recorder: any AudioRecording
    @ObservationIgnored private let save: (RecordedAudio) throws -> Void
    @ObservationIgnored private let activity: (any RecordingActivityControlling)?
    @ObservationIgnored private var requestedAt: ContinuousClock.Instant?
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var eventObserver: Task<Void, Never>?

    /// - Parameters:
    ///   - events: Session interruptions and route changes. Without it the recorder ignores them.
    ///   - activity: Shows the recording on the Lock Screen and in the Dynamic Island.
    ///   - save: Takes ownership of a finished recording (moves the temporary file somewhere permanent).
    init(
        access: MicrophoneAccess,
        recorder: any AudioRecording,
        waveform: LiveWaveform = LiveWaveform(),
        events: (any AudioSessionEventSource)? = nil,
        activity: (any RecordingActivityControlling)? = nil,
        save: @escaping (RecordedAudio) throws -> Void
    ) {
        self.waveform = waveform
        self.access = access
        self.recorder = recorder
        self.save = save
        self.activity = activity
        if let events { observe(events) }
    }

    /// - Parameter requestedAt: When the user asked to record, to measure the time to the first audio.
    func start(requestedAt: ContinuousClock.Instant = .now) async {
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
            startLatency = nil
            self.requestedAt = requestedAt
            activity?.recordingStarted()
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
        activity?.recordingPaused(elapsed: elapsed)
    }

    func resume() {
        guard let next = state.applying(.resume) else { return }
        do {
            // The session may have been taken away while paused (interruption, another app).
            try access.reactivate()
            try recorder.resume()
            state = next
            notice = nil
            activity?.recordingResumed(elapsed: elapsed)
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
        keepCapturedAudio(because: String(localized: "microphone access was turned off"))
    }

    /// Stops and saves the recording.
    func stop() {
        guard let next = state.applying(.stop) else { return }
        stopConsuming()
        defer {
            access.releaseSession()
            activity?.recordingEnded()
        }
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
        activity?.recordingEnded()
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
            keepCapturedAudio(because: String(localized: "audio services were reset"))
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
        activity?.recordingPaused(elapsed: elapsed)
        notice = String(localized: "Paused because another app took the microphone. Tap resume to continue.")
    }

    private func apply(_ sample: RecorderSample) {
        if startLatency == nil, let requestedAt {
            let latency = requestedAt.duration(to: .now)
            startLatency = latency
            StartLatency.report(sinceRequest: latency)
        }
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
        defer {
            access.releaseSession()
            activity?.recordingEnded()
        }
        do {
            let audio = try recorder.stop()
            try save(audio)
            state = .idle
            elapsed = 0
            notice = String(localized: "Recording stopped early (\(reason)). What was captured has been saved.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func stopConsuming() {
        consumer?.cancel()
        consumer = nil
    }
}

extension RecorderViewModel {
    /// Carries out what an intent, a widget or the Live Activity asked for.
    ///
    /// - Parameter beforeStart: Runs only when a recording is really going to start, for example to
    ///   stop playback, which needs a different audio session.
    /// - Returns: The task that starts the recording, `nil` when nothing needs to start.
    @discardableResult
    func handle(
        _ command: QuickCaptureCommand,
        requestedAt instant: ContinuousClock.Instant,
        beforeStart: () -> Void = {}
    ) -> Task<Void, Never>? {
        switch command {
        case .start:
            guard !state.isCapturing else { return nil }
            beforeStart()
            return Task { await start(requestedAt: instant) }
        case .stop:
            stop()
            return nil
        }
    }
}
