import Foundation
import SwiftData
import Testing
@testable import MURMUR

@MainActor
struct RecordingDetailsTests {
    private func makeRepository(_ store: TestStore) throws -> (RecordingRepository, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        return (RecordingRepository(context: container.mainContext, fileStore: store.fileStore), container)
    }

    @Test func renamingChangesTheTitleAndTrimsIt() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let (repository, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [])

        try repository.rename(recording, to: "  Standup  ")
        #expect(recording.title == "Standup")
    }

    @Test func aBlankTitleGoesBackToTheDefaultOne() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let (repository, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [], title: "Mine")

        try repository.rename(recording, to: "   ")
        #expect(recording.title == RecordingRepository.defaultTitle(for: recording.createdAt))
    }

    @Test func titleAndTagsSurviveARelaunch() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let url = store.root.appendingPathComponent("details.sqlite")
        let id: UUID
        do {
            let container = try PersistenceController.makeContainer(storeURL: url)
            let repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
            let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [])
            try repository.updateDetails(recording, title: "Kept", tags: ["a", "b c"])
            id = recording.id
        }

        let reopened = try PersistenceController.makeContainer(storeURL: url)
        let repository = RecordingRepository(context: reopened.mainContext, fileStore: store.fileStore)
        let recording = try #require(repository.recording(withID: id))
        #expect(recording.title == "Kept")
        #expect(recording.tags == ["a", "b c"])
    }

    @Test func tagsAreCleanedWhenStored() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let (repository, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [])

        try repository.setTags(recording, to: ["#Work", "work", "", "Home"])
        #expect(recording.tags == ["Work", "Home"])
    }

    @Test func tagUsageIsOrderedByCountThenName() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let (repository, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        for tags in [["beta", "alpha"], ["Beta"], ["gamma"]] {
            let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 1, waveform: [])
            try repository.setTags(recording, to: tags)
        }

        #expect(repository.allTags() == ["beta", "alpha", "gamma"])
    }
}
