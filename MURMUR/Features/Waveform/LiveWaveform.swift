import Observation

/// The rolling waveform shown while recording.
///
/// Kept apart from `RecorderViewModel` on purpose: levels arrive ~20 times a second, and with their
/// own observable only `WaveformView` re-renders at that rate, not the whole recorder screen.
@MainActor
@Observable
final class LiveWaveform {
    /// How many levels stay visible: 20 Hz → the last 6 seconds.
    static let defaultCapacity = 120

    /// Bumped on every change; reading it subscribes a view to updates.
    private(set) var revision = 0

    @ObservationIgnored private var buffer: WaveformRingBuffer

    init(capacity: Int = LiveWaveform.defaultCapacity) {
        buffer = WaveformRingBuffer(capacity: capacity)
    }

    var capacity: Int { buffer.capacity }
    var count: Int { buffer.count }

    func append(_ level: Float) {
        buffer.append(level)
        revision &+= 1
    }

    func reset() {
        buffer.removeAll()
        revision &+= 1
    }

    /// Level `index` counted from the oldest visible one. Allocation-free, for drawing.
    subscript(index: Int) -> Float { buffer[index] }
}
