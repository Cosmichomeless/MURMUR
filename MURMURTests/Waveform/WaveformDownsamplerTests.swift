import Testing
@testable import MURMUR

struct WaveformDownsamplerTests {
    @Test func shortRecordingsKeepEverySample() {
        var downsampler = WaveformDownsampler(binCount: 10)
        [0.1, 0.5, 0.3].forEach { downsampler.append($0) }

        #expect(downsampler.result == [0.1, 0.5, 0.3])
    }

    @Test func mergesPairsByMaxWhenItReachesTwiceTheBinCount() {
        var downsampler = WaveformDownsampler(binCount: 2)
        [0.1, 0.4, 0.2, 0.3].forEach { downsampler.append($0) } // 4 == 2 * binCount → merge

        #expect(downsampler.result == [0.4, 0.3])
        #expect(downsampler.stride == 2)
    }

    @Test func partialTrailingBinIsIncluded() {
        var downsampler = WaveformDownsampler(binCount: 2)
        [0.1, 0.4, 0.2, 0.3, 0.9].forEach { downsampler.append($0) }

        #expect(downsampler.result == [0.4, 0.3, 0.9])
    }

    @Test func memoryStaysBoundedForVeryLongRecordings() {
        var downsampler = WaveformDownsampler(binCount: 100)
        // 20 Hz for 10 hours.
        for i in 0..<(20 * 3600 * 10) {
            downsampler.append(Float(i % 100) / 100)
            #expect(downsampler.result.count <= 201)
        }

        #expect(downsampler.result.count >= 100)
    }

    @Test func peaksSurviveDownsampling() {
        var downsampler = WaveformDownsampler(binCount: 50)
        for i in 0..<100_000 { downsampler.append(i == 73_001 ? 1.0 : 0.1) }

        #expect(downsampler.result.max() == 1.0)
    }

    @Test func summarySpansTheWholeRecording() {
        var downsampler = WaveformDownsampler(binCount: 50)
        // Ramp 0 → 1: the first bins must be low and the last bins high.
        let total = 50_000
        for i in 0..<total { downsampler.append(Float(i) / Float(total)) }

        let result = downsampler.result
        #expect(result.first! < 0.05)
        #expect(result.last! > 0.95)
    }
}
