#if DEBUG
import AVFoundation

/// Synthetic, speech-like audio: a deterministic loudness envelope and a voice-ish tone shaped by it.
/// The same seed always gives the same levels, so the waveform and the sound repeat exactly.
enum DemoSignal {
    /// Loudness in `0...1` for the `index`-th 50 ms window: words of ~0.3 s with short pauses.
    static func level(at index: Int, seed: UInt64) -> Float {
        let word = index / 6
        // Roughly one phrase in five ends in a pause of about a second.
        if noise(word / 4, seed: seed ^ 0xA5A5) < 0.18 {
            return Float(0.02 + 0.02 * noise(index, seed: seed))
        }
        let position = Double(index % 6 + 1) / 7
        let gain = 0.3 + 0.7 * noise(word, seed: seed)
        let flutter = 0.85 + 0.15 * noise(index, seed: seed &+ 1)
        return Float(min(1, gain * sin(.pi * position) * flutter))
    }

    static func levels(count: Int, seed: UInt64) -> [Float] {
        (0..<count).map { level(at: $0, seed: seed) }
    }

    /// SplitMix64 finalizer mapped to `0..<1`.
    private static func noise(_ value: Int, seed: UInt64) -> Double {
        var x = UInt64(truncatingIfNeeded: value) &+ seed &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 30
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27
        x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x >> 11) / Double(1 << 53)
    }
}

enum DemoAudioError: Error {
    case bufferUnavailable
}

enum DemoAudio {
    static let sampleRate = 44_100.0
    /// Seconds of audio one level describes. Matches the real meter window.
    static let window = RecordingTapProcessor.sampleWindow

    /// Writes an AAC `.m4a` shaped like a real capture (mono, 44.1 kHz, 64 kbit/s) for `levels`.
    static func write(levels: [Float], to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let frames = AVAudioFrameCount(sampleRate * window)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0]
        else { throw DemoAudioError.bufferUnavailable }
        buffer.frameLength = frames

        var elapsed = 0.0
        for level in levels {
            let amplitude = Double(level) * 0.5
            for frame in 0..<Int(frames) {
                let time = elapsed + Double(frame) / sampleRate
                let tone = sin(2 * .pi * 180 * time) + 0.5 * sin(2 * .pi * 360 * time) + 0.25 * sin(2 * .pi * 540 * time)
                samples[frame] = Float(amplitude * tone / 1.75)
            }
            elapsed += Double(frames) / sampleRate
            try file.write(from: buffer)
        }
    }

    /// The bounded summary a real capture would have saved for `levels`.
    static func waveform(for levels: [Float]) -> [Float] {
        var downsampler = WaveformDownsampler(binCount: RecordingTapProcessor.waveformBinCount)
        for level in levels { downsampler.append(level) }
        return downsampler.result
    }
}
#endif
