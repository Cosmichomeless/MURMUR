import Foundation

/// What the library tells the audio sync about: audio files appearing and disappearing.
///
/// The metadata of a note travels through SwiftData's CloudKit mirror; the audio does not fit
/// there, so it has its own channel (`CloudKitAudioSync`). The repository calls these after the
/// matching change to the store was saved, never before.
protocol AudioSyncing: AnyObject, Sendable {
    /// A new audio file exists locally and has to reach the other devices.
    func audioAdded(fileName: String)
    /// The note was deleted; its audio has to disappear from the other devices.
    func audioRemoved(fileName: String)
}

/// Rules for audio coming from iCloud, kept apart from CloudKit so they can be tested.
enum AudioSyncRules {
    /// `<UUID>.m4a`: the only shape `RecordingFileStore.commit` ever produces.
    ///
    /// A name arriving from the cloud is data from outside the app, so anything else (a path,
    /// `..`, another extension) is refused instead of being used to build a file location.
    static func isValidFileName(_ name: String) -> Bool {
        guard name.hasSuffix("." + RecordingFileStore.fileExtension) else { return false }
        let stem = String(name.dropLast(RecordingFileStore.fileExtension.count + 1))
        return UUID(uuidString: stem) != nil && stem.count == 36
    }
}

extension RecordingFileStore {
    /// Stores audio that arrived from iCloud under its own name. First writer wins.
    ///
    /// Audio is immutable: a name is written once and never replaced, so a second download of
    /// the same name (or a name the user already has) leaves the existing file alone.
    /// - Returns: `true` when a file was written.
    @discardableResult
    func adoptDownloaded(fileName: String, from source: URL) throws -> Bool {
        guard AudioSyncRules.isValidFileName(fileName) else { return false }
        try prepareDirectories()
        guard !exists(fileName: fileName) else { return false }
        // Copy next to the destination first so the final step is an atomic rename: a file with
        // the final name is never half written.
        let staging = makeTemporaryURL()
        try FileManager.default.copyItem(at: source, to: staging)
        do {
            try FileManager.default.moveItem(at: staging, to: fileURL(for: fileName))
        } catch {
            removeTemporary(at: staging)
            if exists(fileName: fileName) { return false }
            throw error
        }
        return true
    }
}
