import Foundation
import Testing
@testable import MURMUR

struct RecordingFileStoreTests {
    @Test func temporaryURLsAreUniqueAndInsideTheTemporaryDirectory() {
        let store = TestStore()
        defer { store.cleanUp() }
        let first = store.fileStore.makeTemporaryURL()
        let second = store.fileStore.makeTemporaryURL()
        #expect(first != second)
        #expect(first.deletingLastPathComponent() == store.fileStore.temporaryDirectory)
        #expect(first.pathExtension == "m4a")
    }

    @Test func commitMovesTheFileIntoRecordings() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let temporary = store.writeTemporaryFile()

        let fileName = try store.fileStore.commit(temporaryURL: temporary)

        #expect(store.fileStore.exists(fileName: fileName))
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
        #expect(try store.fileStore.storedFileNames() == [fileName])
    }

    @Test func commitOfMissingFileThrowsAndLeavesRecordingsUntouched() {
        let store = TestStore()
        defer { store.cleanUp() }
        #expect(throws: (any Error).self) {
            try store.fileStore.commit(temporaryURL: store.fileStore.makeTemporaryURL())
        }
        #expect((try? store.fileStore.storedFileNames()) == [])
    }

    @Test func removeDeletesTheFileAndToleratesMissingOnes() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let name = store.writeRecordingFile()

        try store.fileStore.remove(fileName: name)
        #expect(!store.fileStore.exists(fileName: name))
        try store.fileStore.remove(fileName: name)
    }

    @Test func storedFileNamesIgnoresOtherExtensions() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let name = store.writeRecordingFile()
        store.writeRecordingFile(named: "notes.txt")
        #expect(try store.fileStore.storedFileNames() == [name])
    }

    @Test func purgeTemporaryFilesEmptiesTheTemporaryDirectory() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        _ = store.writeTemporaryFile()
        _ = store.writeTemporaryFile()

        #expect(try store.fileStore.purgeTemporaryFiles() == 2)
        #expect(try store.fileStore.purgeTemporaryFiles() == 0)
    }
}
