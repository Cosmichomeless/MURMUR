import Testing
@testable import MURMUR

struct WaveformRingBufferTests {
    @Test func keepsInsertionOrderBeforeItFills() {
        var buffer = WaveformRingBuffer(capacity: 4)
        [0.1, 0.2, 0.3].forEach { buffer.append($0) }

        #expect(buffer.count == 3)
        #expect(buffer.elements == [0.1, 0.2, 0.3])
    }

    @Test func overwritesTheOldestOnceFull() {
        var buffer = WaveformRingBuffer(capacity: 3)
        (1...5).forEach { buffer.append(Float($0)) }

        #expect(buffer.count == 3)
        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer[0] == 3)
        #expect(buffer[2] == 5)
    }

    @Test func neverGrowsPastItsCapacity() {
        var buffer = WaveformRingBuffer(capacity: 120)
        for i in 0..<1_000_000 { buffer.append(Float(i % 7) / 7) }

        #expect(buffer.count == 120)
        #expect(buffer.capacity == 120)
        #expect(buffer.elements.count == 120)
    }

    @Test func removeAllStartsOver() {
        var buffer = WaveformRingBuffer(capacity: 3)
        (1...5).forEach { buffer.append(Float($0)) }
        buffer.removeAll()
        buffer.append(9)

        #expect(buffer.elements == [9])
    }
}
