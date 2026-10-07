import Testing
@testable import MURMUR

/// The waveform structures must stay bounded however long the recording is. These compare them
/// against a trivially correct model and check the bounds after every single append.
struct WaveformBoundsTests {
    @Test(arguments: [1, 2, 3, 7, 120])
    func ringBufferMatchesTheLastNOfAReferenceArray(capacity: Int) {
        var generator = SeededGenerator(seed: UInt64(capacity))
        var buffer = WaveformRingBuffer(capacity: capacity)
        var reference: [Float] = []

        for _ in 0..<1_000 {
            let level = Float.random(in: 0...1, using: &generator)
            buffer.append(level)
            reference.append(level)

            #expect(buffer.count == min(reference.count, capacity))
            #expect(buffer.elements == Array(reference.suffix(capacity)))
        }
    }

    @Test func ringBufferIsReusableAfterRemoveAllEvenMidWrap() {
        var buffer = WaveformRingBuffer(capacity: 4)
        (1...6).forEach { buffer.append(Float($0)) } // head is mid-buffer now

        buffer.removeAll()
        #expect(buffer.count == 0)

        (10...12).forEach { buffer.append(Float($0)) }
        #expect(buffer.elements == [10, 11, 12])
    }

    @Test @MainActor func liveWaveformShowsExactlyTheLastSixSecondsAtTwentyHertz() {
        let waveform = LiveWaveform()
        #expect(waveform.capacity == 120)

        for i in 0..<(20 * 60 * 60) { waveform.append(Float(i % 10) / 10) } // one hour
        #expect(waveform.count == 120)
    }

    @Test(arguments: [1, 2, 3, 10, 100])
    func downsamplerStaysWithinBoundsAfterEveryAppend(binCount: Int) {
        var generator = SeededGenerator(seed: UInt64(binCount))
        var downsampler = WaveformDownsampler(binCount: binCount)
        var peak: Float = 0

        for seen in 1...5_000 {
            let level = Float.random(in: 0...1, using: &generator)
            peak = max(peak, level)
            downsampler.append(level)

            let result = downsampler.result
            #expect(result.count <= 2 * binCount + 1)
            if seen >= 2 * binCount { #expect(result.count >= binCount) }
            #expect(downsampler.stride.nonzeroBitCount == 1, "stride is a power of two")
        }
        #expect(downsampler.result.max() == peak, "downsampling never loses the loudest moment")
    }

    @Test func downsamplerDoesNotGrowWithRecordingLength() {
        var short = WaveformDownsampler(binCount: 100)
        var long = WaveformDownsampler(binCount: 100)

        for i in 0..<10_000 { short.append(Float(i % 10) / 10) }
        for i in 0..<2_000_000 { long.append(Float(i % 10) / 10) } // ~28 hours at 20 Hz

        #expect(long.result.count <= 201)
        #expect(abs(long.result.count - short.result.count) <= 100)
    }
}
