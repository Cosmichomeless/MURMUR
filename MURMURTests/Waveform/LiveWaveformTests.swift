import Testing
@testable import MURMUR

@MainActor
struct LiveWaveformTests {
    @Test func appendingAdvancesTheRevisionSoViewsRedraw() {
        let waveform = LiveWaveform(capacity: 10)
        let before = waveform.revision
        waveform.append(0.5)

        #expect(waveform.revision != before)
        #expect(waveform.count == 1)
        #expect(waveform[0] == 0.5)
    }

    @Test func staysWithinCapacity() {
        let waveform = LiveWaveform(capacity: 5)
        for i in 0..<1_000 { waveform.append(Float(i)) }

        #expect(waveform.count == 5)
        #expect(waveform[0] == 995)
        #expect(waveform[4] == 999)
    }

    @Test func resetEmptiesIt() {
        let waveform = LiveWaveform(capacity: 5)
        waveform.append(1)
        waveform.reset()

        #expect(waveform.count == 0)
    }
}
