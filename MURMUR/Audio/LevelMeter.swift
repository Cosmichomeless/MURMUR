import Accelerate
import AVFoundation

/// Converts audio buffers into a 0...1 level suitable for drawing.
enum LevelMeter {
    /// Quietest level that still maps above zero, in decibels.
    static let floorDecibels: Float = -60

    /// Root-mean-square amplitude of the first channel (linear, 0...1 for full-scale input).
    static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var value: Float = 0
        vDSP_rmsqv(channel, 1, &value, vDSP_Length(buffer.frameLength))
        return value
    }

    /// Maps a linear amplitude to 0...1 on a decibel scale (silence → 0, full scale → 1).
    static func normalizedLevel(fromRMS rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        let level = (decibels - floorDecibels) / -floorDecibels
        return min(max(level, 0), 1)
    }
}
