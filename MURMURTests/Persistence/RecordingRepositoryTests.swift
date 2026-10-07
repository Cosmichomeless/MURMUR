import Foundation
import SwiftData
import Testing
@testable import MURMUR

@MainActor
struct RecordingRepositoryTests {
    /// The container must outlive the context (a `ModelContext` does not retain it), so it is returned too.
    private func makeRepository(_ store: TestStore) throws -> (RecordingRepository, ModelContext, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        return (RecordingRepository(context: context, fileStore: store.fileStore), context, container)
    }

    @Test func saveCommitsTheFileAndStoresTheMetadata() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (repository, context, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let temporary = store.writeTemporaryFile()

        let recording = try repository.save(temporaryURL: temporary, duration: 12.5, waveform: [0.1, 0.9])

        #expect(store.fileStore.exists(fileName: recording.fileName))
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
        #expect(recording.duration == 12.5)
        #expect(recording.waveform == [0.1, 0.9])
        #expect(try context.fetch(FetchDescriptor<Recording>()).count == 1)
    }

    @Test func titleDefaultsToTheCreationDate() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (repository, _, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let recording = try repository.save(
            temporaryURL: store.writeTemporaryFile(), duration: 1, waveform: [], createdAt: date
        )

        #expect(recording.title == RecordingRepository.defaultTitle(for: date))
        #expect(recording.title.hasPrefix("Recording "))
    }

    @Test func aMissingCaptureSavesNothing() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (repository, context, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let missing = store.fileStore.makeTemporaryURL() // never written

        #expect(throws: (any Error).self) {
            try repository.save(temporaryURL: missing, duration: 1, waveform: [])
        }
        #expect(try context.fetch(FetchDescriptor<Recording>()).isEmpty)
        #expect(try store.fileStore.storedFileNames().isEmpty)
    }

    @Test func libraryOrderIsNewestFirst() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (repository, context, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        for (offset, name) in [(0, "old"), (200, "newest"), (100, "middle")] {
            try repository.save(
                temporaryURL: store.writeTemporaryFile(),
                duration: 1,
                waveform: [],
                title: name,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(offset))
            )
        }

        let titles = try context.fetch(Recording.newestFirst()).map(\.title)
        #expect(titles == ["newest", "middle", "old"])
    }

    @Test func recordingsSurviveARelaunch() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let storeURL = store.root.appendingPathComponent("library.store")

        let firstLaunch = try PersistenceController.makeContainer(storeURL: storeURL)
        let repository = RecordingRepository(context: firstLaunch.mainContext, fileStore: store.fileStore)
        let saved = try repository.save(
            temporaryURL: store.writeTemporaryFile(), duration: 42, waveform: [0.25, 0.75], title: "Standup"
        )
        let id = saved.id

        // A new container over the same files is what the app sees after being killed and reopened.
        let secondLaunch = try PersistenceController.makeContainer(storeURL: storeURL)
        let restored = try secondLaunch.mainContext.fetch(Recording.newestFirst())

        #expect(restored.count == 1)
        #expect(restored[0].id == id)
        #expect(restored[0].title == "Standup")
        #expect(restored[0].duration == 42)
        #expect(restored[0].waveform == [0.25, 0.75])
        #expect(store.fileStore.exists(fileName: restored[0].fileName))
    }
}
