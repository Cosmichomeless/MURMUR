import Foundation
import SwiftData
import Testing
@testable import MURMUR

@MainActor
struct RecordingModelTests {
    @Test func waveformRoundTripsThroughData() {
        let samples: [Float] = [0, 0.25, 0.5, 1]
        #expect(WaveformCodec.decode(WaveformCodec.encode(samples)) == samples)
    }

    @Test func emptyAndTruncatedWaveformDataDecodeSafely() {
        #expect(WaveformCodec.decode(Data()) == [])
        #expect(WaveformCodec.decode(Data([1, 2, 3])) == [])
    }

    @Test func recordingStoresAllRequestedFields() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000)
        context.insert(Recording(id: id, title: "Idea", fileName: "a.m4a", duration: 12.5, createdAt: date, waveform: [0.1, 0.9]))
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Recording>()).first)
        #expect(fetched.id == id)
        #expect(fetched.title == "Idea")
        #expect(fetched.fileName == "a.m4a")
        #expect(fetched.duration == 12.5)
        #expect(fetched.createdAt == date)
        #expect(fetched.waveform == [0.1, 0.9])
    }

    @Test func fileURLResolvesAgainstTheStore() {
        let store = TestStore()
        defer { store.cleanUp() }
        let recording = Recording(title: "x", fileName: "abc.m4a", duration: 1)
        #expect(recording.fileURL(in: store.fileStore) == store.fileStore.recordingsDirectory.appendingPathComponent("abc.m4a"))
    }
}
