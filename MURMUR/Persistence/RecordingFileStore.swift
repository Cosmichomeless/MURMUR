import Foundation

/// Owns every audio file location and the operations on them. It knows nothing about SwiftData.
///
/// Two directories:
/// - `temporaryDirectory`: files being captured. Never referenced by metadata. Disposable.
/// - `recordingsDirectory`: finished recordings. Every file here should have a `Recording`.
///
/// Both directories must be on the same volume so `commit` is an atomic rename.
struct RecordingFileStore: Sendable {
    static let fileExtension = "m4a"

    let recordingsDirectory: URL
    let temporaryDirectory: URL

    init(recordingsDirectory: URL, temporaryDirectory: URL) {
        self.recordingsDirectory = recordingsDirectory
        self.temporaryDirectory = temporaryDirectory
    }

    /// `Application Support/Recordings` (backed up, not user-visible) and `tmp/Recording`.
    static var `default`: RecordingFileStore {
        let fileManager = FileManager.default
        let support = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return RecordingFileStore(
            recordingsDirectory: support.appendingPathComponent("Recordings", isDirectory: true),
            temporaryDirectory: fileManager.temporaryDirectory.appendingPathComponent("Recording", isDirectory: true)
        )
    }

    func prepareDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Locations

    func fileURL(for fileName: String) -> URL {
        recordingsDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// A fresh, unique location for a capture in progress.
    func makeTemporaryURL() -> URL {
        temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension(Self.fileExtension)
    }

    // MARK: - Lifecycle

    /// Moves a finished capture into `recordingsDirectory` and returns its file name.
    ///
    /// A rename on the same volume: after it returns the file is either fully in place or the
    /// call threw and the temporary file is untouched.
    func commit(temporaryURL: URL) throws -> String {
        try prepareDirectories()
        let fileName = UUID().uuidString + "." + Self.fileExtension
        try FileManager.default.moveItem(at: temporaryURL, to: fileURL(for: fileName))
        return fileName
    }

    /// Deletes a recording file. A file that is already gone is not an error.
    func remove(fileName: String) throws {
        do {
            try FileManager.default.removeItem(at: fileURL(for: fileName))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    /// Deletes a temporary capture. A file that is already gone is not an error.
    func removeTemporary(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func exists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    // MARK: - Inspection

    /// Names of the audio files currently in `recordingsDirectory`.
    func storedFileNames() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: recordingsDirectory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return Set(urls.filter { $0.pathExtension == Self.fileExtension }.map(\.lastPathComponent))
    }

    /// Deletes everything in `temporaryDirectory` and returns how many files were removed.
    ///
    /// Safe at launch only: no capture can be in progress then.
    @discardableResult
    func purgeTemporaryFiles() throws -> Int {
        guard FileManager.default.fileExists(atPath: temporaryDirectory.path) else { return 0 }
        let urls = try FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
        return urls.count
    }
}
