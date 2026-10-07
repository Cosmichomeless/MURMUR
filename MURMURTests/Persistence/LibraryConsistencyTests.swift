import Foundation
import SwiftData
import Testing
@testable import MURMUR

/// Whatever sequence of saves and deletes happens, the library and the files on disk must agree.
@MainActor
struct LibraryConsistencyTests {
    @MainActor
    private struct Environment {
        let store = TestStore()
        let container: ModelContainer
        let repository: RecordingRepository

        init() throws {
            container = try PersistenceController.makeContainer(inMemory: true)
            repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
        }

        var context: ModelContext { container.mainContext }

        func listedFileNames() throws -> Set<String> {
            Set(try context.fetch(FetchDescriptor<Recording>()).map(\.fileName))
        }
    }

    @Test func randomSavesAndDeletesKeepFilesAndMetadataInStep() throws {
        let env = try Environment()
        defer { env.store.cleanUp(); withExtendedLifetime(env.container) {} }
        var generator = SeededGenerator(seed: 42)
        var live: [Recording] = []

        for step in 0..<200 {
            if live.isEmpty || Bool.random(using: &generator) {
                live.append(try env.repository.save(
                    temporaryURL: env.store.writeTemporaryFile(),
                    duration: Double(step),
                    waveform: []
                ))
            } else {
                let victim = live.remove(at: Int.random(in: 0..<live.count, using: &generator))
                #expect(try env.repository.delete(victim) == .deleted)
            }

            let listed = try env.listedFileNames()
            #expect(listed == Set(live.map(\.fileName)), "step \(step): library vs expected")
            #expect(try env.store.fileStore.storedFileNames() == listed, "step \(step): files vs library")
        }

        // Nothing for the launch-time sweep to fix.
        let report = try RecordingReconciler(context: env.context, fileStore: env.store.fileStore).run()
        #expect(report == ReconciliationReport(
            removedOrphanFiles: 0, removedRecordingsMissingFile: 0, purgedTemporaryFiles: 0
        ))
    }

    @Test func deletingEverythingLeavesAnEmptyLibraryAndFolder() throws {
        let env = try Environment()
        defer { env.store.cleanUp(); withExtendedLifetime(env.container) {} }
        let recordings = try (0..<25).map { _ in
            try env.repository.save(temporaryURL: env.store.writeTemporaryFile(), duration: 1, waveform: [])
        }

        for recording in recordings { try env.repository.delete(recording) }

        #expect(try env.listedFileNames().isEmpty)
        #expect(try env.store.fileStore.storedFileNames().isEmpty)
    }

    @Test func aCrashBetweenStepsIsRepairedAndLeavesNothingOrphaned() throws {
        let env = try Environment()
        defer { env.store.cleanUp(); withExtendedLifetime(env.container) {} }
        let kept = try env.repository.save(temporaryURL: env.store.writeTemporaryFile(), duration: 1, waveform: [])
        let lostFile = try env.repository.save(temporaryURL: env.store.writeTemporaryFile(), duration: 1, waveform: [])

        // Crash during save: the file was committed but the metadata never was.
        let orphan = env.store.writeRecordingFile()
        // Crash during delete the other way round: the file vanished but the metadata is still there.
        try FileManager.default.removeItem(at: env.store.fileStore.fileURL(for: lostFile.fileName))
        // Crash while recording: a temporary file was left behind.
        _ = env.store.writeTemporaryFile()

        let report = try RecordingReconciler(context: env.context, fileStore: env.store.fileStore).run()

        #expect(report == ReconciliationReport(
            removedOrphanFiles: 1, removedRecordingsMissingFile: 1, purgedTemporaryFiles: 1
        ))
        #expect(try env.listedFileNames() == [kept.fileName])
        #expect(try env.store.fileStore.storedFileNames() == [kept.fileName])
        #expect(!env.store.fileStore.exists(fileName: orphan))
    }

    // MARK: - From the recorder to the library

    private func makeRecorderModel(
        _ env: Environment,
        recorder: FakeAudioRecorder,
        events: FakeAudioSessionEvents = FakeAudioSessionEvents()
    ) -> RecorderViewModel {
        RecorderViewModel(
            access: MicrophoneAccess(session: FakeAudioSession(permission: .granted)),
            recorder: recorder,
            events: events,
            save: { audio in
                _ = try env.repository.save(
                    temporaryURL: audio.fileURL, duration: audio.duration, waveform: audio.waveform
                )
            }
        )
    }

    @Test func aStoppedRecordingIsListedAndItsFileIsStored() async throws {
        let env = try Environment()
        defer { env.store.cleanUp(); withExtendedLifetime(env.container) {} }
        let recorder = FakeAudioRecorder()
        recorder.recorded = RecordedAudio(fileURL: env.store.writeTemporaryFile(), duration: 5, waveform: [0.5])
        let model = makeRecorderModel(env, recorder: recorder)

        await model.start()
        model.stop()

        let recordings = try env.context.fetch(Recording.newestFirst())
        #expect(recordings.count == 1)
        #expect(env.store.fileStore.exists(fileName: recordings[0].fileName))
        #expect(try env.store.fileStore.storedFileNames() == [recordings[0].fileName])
    }

    @Test func aDiscardedRecordingLeavesNothingInTheLibrary() async throws {
        let env = try Environment()
        defer { env.store.cleanUp(); withExtendedLifetime(env.container) {} }
        let model = makeRecorderModel(env, recorder: FakeAudioRecorder())

        await model.start()
        model.discard()

        #expect(try env.listedFileNames().isEmpty)
        #expect(try env.store.fileStore.storedFileNames().isEmpty)
    }

    @Test func anInterruptedRecordingStillEndsUpInTheLibrary() async throws {
        let env = try Environment()
        defer { env.store.cleanUp(); withExtendedLifetime(env.container) {} }
        let recorder = FakeAudioRecorder()
        recorder.recorded = RecordedAudio(fileURL: env.store.writeTemporaryFile(), duration: 9, waveform: [])
        let events = FakeAudioSessionEvents()
        let model = makeRecorderModel(env, recorder: recorder, events: events)
        await model.start()

        events.send(.mediaServicesReset)
        for _ in 0..<5 { await Task.yield() }

        let recordings = try env.context.fetch(Recording.newestFirst())
        #expect(recordings.map(\.duration) == [9])
        #expect(try env.store.fileStore.storedFileNames() == [recordings[0].fileName])
    }
}
