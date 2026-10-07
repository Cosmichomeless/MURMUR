import Foundation

/// Converts a waveform envelope to and from the bytes stored in `Recording.waveformData`.
///
/// Values are little-endian-agnostic native `Float`s: the data never leaves the device.
enum WaveformCodec {
    static func encode(_ samples: [Float]) -> Data {
        samples.withUnsafeBytes { Data($0) }
    }

    static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        guard count > 0 else { return [] }
        var samples = [Float](repeating: 0, count: count)
        samples.withUnsafeMutableBytes { destination in
            _ = data.copyBytes(to: destination, count: count * MemoryLayout<Float>.size)
        }
        return samples
    }
}
