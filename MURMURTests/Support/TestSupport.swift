import Foundation
@testable import MURMUR

/// A file store rooted in a unique temporary folder, removed by `cleanUp()`.
struct TestStore {
    let root: URL
    let fileStore: RecordingFileStore

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MURMURTests-\(UUID().uuidString)", isDirectory: true)
        fileStore = RecordingFileStore(
            recordingsDirectory: root.appendingPathComponent("Recordings", isDirectory: true),
            temporaryDirectory: root.appendingPathComponent("Temporary", isDirectory: true)
        )
        try? fileStore.prepareDirectories()
    }

    /// Writes a placeholder audio file and returns its name.
    @discardableResult
    func writeRecordingFile(named name: String = UUID().uuidString + ".m4a") -> String {
        FileManager.default.createFile(atPath: fileStore.fileURL(for: name).path, contents: Data([1, 2, 3]))
        return name
    }

    func writeTemporaryFile() -> URL {
        let url = fileStore.makeTemporaryURL()
        FileManager.default.createFile(atPath: url.path, contents: Data([1, 2, 3]))
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
