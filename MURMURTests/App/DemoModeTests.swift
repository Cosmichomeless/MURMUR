import AVFoundation
import Foundation
import Testing
@testable import MURMUR

/// The demo is what the README screenshots come from, so it must stay deterministic and must run
/// the production persistence and playback code rather than a lookalike.
@MainActor
struct DemoModeTests {
    @Test func theSyntheticVoiceIsDeterministicAndInRange() {
        let first = DemoSignal.levels(count: 400, seed: 11)
        let second = DemoSignal.levels(count: 400, seed: 11)
        #expect(first == second)
        #expect(first != DemoSignal.levels(count: 400, seed: 12))
        #expect(first.allSatisfy { (0...1).contains($0) })
        // It has both speech and pauses, so the waveform has some shape.
        #expect(first.contains { $0 > 0.5 })
        #expect(first.contains { $0 < 0.05 })
    }

    @Test func synthesizedAudioIsAPlayableFileOfTheRightLength() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let url = store.fileStore.makeTemporaryURL()

        try DemoAudio.write(levels: DemoSignal.levels(count: 60, seed: 1), to: url)

        let player = try AVAudioPlayer(contentsOf: url)
        #expect(abs(player.duration - 3.0) < 0.15)
    }

    @Test func theDemoLibraryIsSavedThroughTheRealRepository() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let container = try PersistenceController.makeContainer(inMemory: true)
        let repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)

        try DemoLibrary.populate(repository)

        let recordings = try container.mainContext.fetch(Recording.newestFirst())
        #expect(recordings.count == DemoLibrary.recordingCount)
        #expect(Set(recordings.map(\.title)).count == recordings.count)
        for recording in recordings {
            #expect(store.fileStore.exists(fileName: recording.fileName), "\(recording.title) has its file")
            #expect(!recording.waveform.isEmpty)
            #expect(recording.waveform.count <= 2 * RecordingTapProcessor.waveformBinCount + 1)
        }
        #expect(try store.fileStore.storedFileNames().count == recordings.count)
    }

    @Test func theDemoRecorderFeedsTheRecorderViewModelAndSavesARecording() async throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let container = try PersistenceController.makeContainer(inMemory: true)
        let repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
        let access = MicrophoneAccess(session: DemoSession(playback: FakeAudioSession()))
        let model = RecorderViewModel(
            access: access,
            recorder: DemoRecorder(store: store.fileStore),
            save: { audio in
                try repository.save(temporaryURL: audio.fileURL, duration: audio.duration, waveform: audio.waveform)
            }
        )

        await model.start()
        #expect(model.state == .recording)
        while model.elapsed < 0.5 { try await Task.sleep(for: .milliseconds(20)) }
        model.stop()

        #expect(model.state == .idle)
        #expect(model.savedCount == 1)
        let saved = try #require(try container.mainContext.fetch(Recording.newestFirst()).first)
        #expect(saved.duration >= 0.5)
        #expect(store.fileStore.exists(fileName: saved.fileName))
    }

    @Test func discardingADemoCaptureLeavesNothingBehind() async throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let recorder = DemoRecorder(store: store.fileStore)

        let stream = try recorder.start()
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        recorder.discard()

        #expect(try FileManager.default.contentsOfDirectory(atPath: store.fileStore.temporaryDirectory.path).isEmpty)
        #expect(throws: AudioRecorderError.notRecording) { try recorder.stop() }
    }
}
