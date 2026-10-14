import Foundation
import SwiftData
import Testing
@testable import MURMUR

struct AudioSyncRulesTests {
    @Test func acceptsOnlyUUIDNamedM4AFiles() {
        #expect(AudioSyncRules.isValidFileName(UUID().uuidString + ".m4a"))
    }

    @Test(arguments: [
        "../x.m4a",
        "a/b.m4a",
        "..",
        "",
        ".m4a",
        "notes.m4a",
        "5F3B1E0A-0000-0000-0000-000000000000.mp3",
        "5F3B1E0A-0000-0000-0000-000000000000",
        "5F3B1E0A-0000-0000-0000-000000000000.m4a/..",
    ])
    func refusesAnythingElse(_ name: String) {
        #expect(!AudioSyncRules.isValidFileName(name))
    }
}

struct AdoptDownloadedTests {
    private func download(in store: TestStore, contents: [UInt8] = [9, 9, 9]) -> URL {
        let url = store.root.appendingPathComponent("download-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: url.path, contents: Data(contents))
        return url
    }

    @Test func writesAFileThatIsNotThereYet() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let name = UUID().uuidString + ".m4a"

        let written = try store.fileStore.adoptDownloaded(fileName: name, from: download(in: store))

        #expect(written)
        #expect(try Data(contentsOf: store.fileStore.fileURL(for: name)) == Data([9, 9, 9]))
    }

    @Test func neverOverwritesAnExistingFile() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let name = store.writeRecordingFile() // contains [1, 2, 3]

        let written = try store.fileStore.adoptDownloaded(fileName: name, from: download(in: store))

        #expect(!written)
        #expect(try Data(contentsOf: store.fileStore.fileURL(for: name)) == Data([1, 2, 3]))
    }

    @Test func refusesAnInvalidName() throws {
        let store = TestStore()
        defer { store.cleanUp() }

        let written = try store.fileStore.adoptDownloaded(fileName: "../escape.m4a", from: download(in: store))

        #expect(!written)
        #expect(!FileManager.default.fileExists(atPath: store.root.appendingPathComponent("escape.m4a").path))
        #expect(try store.fileStore.storedFileNames().isEmpty)
    }

    @Test func leavesNoStagingFileBehind() throws {
        let store = TestStore()
        defer { store.cleanUp() }

        try store.fileStore.adoptDownloaded(fileName: UUID().uuidString + ".m4a", from: download(in: store))

        let leftovers = try FileManager.default.contentsOfDirectory(
            at: store.fileStore.temporaryDirectory, includingPropertiesForKeys: nil
        )
        #expect(leftovers.isEmpty)
    }
}

@MainActor
struct SyncSettingsTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "MURMURTests-\(UUID().uuidString)")!
    }

    @Test func isOffByDefault() {
        let defaults = makeDefaults()
        #expect(!SyncSettings(defaults: defaults).isEnabled)
        #expect(!SyncSettings.requested(defaults: defaults))
    }

    @Test func theChoiceIsRememberedAcrossLaunches() {
        let defaults = makeDefaults()
        SyncSettings(defaults: defaults).isEnabled = true

        #expect(SyncSettings(defaults: defaults).isEnabled)
        #expect(SyncSettings.requested(defaults: defaults))
    }

    @Test func aChangeNeedsARestartUntilTheLaunchMatchesIt() {
        let settings = SyncSettings(defaults: makeDefaults())
        settings.markActive(false)
        #expect(!settings.needsRestart)

        settings.isEnabled = true
        #expect(settings.needsRestart)

        settings.markActive(true)
        #expect(!settings.needsRestart)
    }

    @Test func arrivingAudioBumpsTheRevision() {
        let settings = SyncSettings(defaults: makeDefaults())
        let before = settings.audioRevision
        settings.audioDidArrive()
        #expect(settings.audioRevision == before + 1)
    }
}

@MainActor
struct SyncReconciliationTests {
    private let day: TimeInterval = 24 * 60 * 60

    private func makeContext() throws -> (ModelContext, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        return (container.mainContext, container)
    }

    @Test func keepsANoteWhoseAudioHasNotArrived() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (context, container) = try makeContext()
        defer { withExtendedLifetime(container) {} }
        context.insert(Recording(title: "waiting", fileName: "missing.m4a", duration: 1))
        try context.save()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore, syncEnabled: true).run()

        #expect(report.removedRecordingsMissingFile == 0)
        #expect(report.recordingsAwaitingAudio == 1)
        #expect(try context.fetch(FetchDescriptor<Recording>()).count == 1)
    }

    @Test func withoutSyncANoteWithoutAudioIsStillRemoved() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (context, container) = try makeContext()
        defer { withExtendedLifetime(container) {} }
        context.insert(Recording(title: "broken", fileName: "missing.m4a", duration: 1))
        try context.save()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore).run()

        #expect(report.removedRecordingsMissingFile == 1)
        #expect(report.recordingsAwaitingAudio == 0)
        #expect(try context.fetch(FetchDescriptor<Recording>()).isEmpty)
    }

    @Test func keepsRecentOrphansAndRemovesOldOnesWithSync() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (context, container) = try makeContext()
        defer { withExtendedLifetime(container) {} }
        let orphan = store.writeRecordingFile()
        let written = try #require(store.fileStore.modificationDate(fileName: orphan))

        var reconciler = RecordingReconciler(context: context, fileStore: store.fileStore, syncEnabled: true)
        reconciler.now = written.addingTimeInterval(day)
        #expect(try reconciler.run().removedOrphanFiles == 0)
        #expect(store.fileStore.exists(fileName: orphan))

        reconciler.now = written.addingTimeInterval(RecordingReconciliation.syncOrphanGracePeriod + day)
        #expect(try reconciler.run().removedOrphanFiles == 1)
        #expect(!store.fileStore.exists(fileName: orphan))
    }

    @Test func removesExtraNotesWithTheSameIDKeepingTheOldest() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (context, container) = try makeContext()
        defer { withExtendedLifetime(container) {} }
        let file = store.writeRecordingFile()
        let id = UUID()
        let old = Date(timeIntervalSince1970: 1_000)
        context.insert(Recording(id: id, title: "newer", fileName: file, duration: 1, createdAt: old.addingTimeInterval(60)))
        context.insert(Recording(id: id, title: "older", fileName: file, duration: 1, createdAt: old))
        context.insert(Recording(title: "other", fileName: store.writeRecordingFile(), duration: 1))
        try context.save()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore).run()

        #expect(report.removedDuplicates == 1)
        let titles = try context.fetch(FetchDescriptor<Recording>()).map(\.title).sorted()
        #expect(titles == ["older", "other"])
    }
}

@MainActor
struct RepositoryAudioSyncTests {
    private func makeRepository(_ store: TestStore, sync: FakeAudioSync) throws -> (RecordingRepository, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        var repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
        repository.audioSync = sync
        return (repository, container)
    }

    @Test func savingTellsTheSyncAboutTheNewAudio() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let sync = FakeAudioSync()
        let (repository, container) = try makeRepository(store, sync: sync)
        defer { withExtendedLifetime(container) {} }

        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 1, waveform: [])

        #expect(sync.calls == [.added(recording.fileName)])
    }

    @Test func deletingTellsTheSyncTheAudioIsGone() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let sync = FakeAudioSync()
        let (repository, container) = try makeRepository(store, sync: sync)
        defer { withExtendedLifetime(container) {} }
        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 1, waveform: [])
        let fileName = recording.fileName

        try repository.delete(recording)

        #expect(sync.calls == [.added(fileName), .removed(fileName)])
    }

    @Test func aFailedSaveTellsTheSyncNothing() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let sync = FakeAudioSync()
        let (repository, container) = try makeRepository(store, sync: sync)
        defer { withExtendedLifetime(container) {} }
        let missing = store.root.appendingPathComponent("not-there.m4a")

        #expect(throws: (any Error).self) {
            try repository.save(temporaryURL: missing, duration: 1, waveform: [])
        }

        #expect(sync.calls.isEmpty)
    }
}
