import Foundation

/// The pieces that differ between a normal launch and a demo launch. Everything above this seam
/// (view models, views, repository) is identical in both.
@MainActor
struct AppServices {
    let fileStore: RecordingFileStore
    /// Keep the metadata in memory only (demo runs must never touch the real library).
    let inMemory: Bool
    let session: any AudioSessionControlling
    let recorder: any AudioRecording
    /// Fills the library before the first screen. `nil` in a normal launch.
    let seedLibrary: ((RecordingRepository) throws -> Void)?

    static func make() -> AppServices {
        #if DEBUG
        if DemoMode.isEnabled {
            let store = DemoMode.makeFileStore()
            let seed: ((RecordingRepository) throws -> Void)? = DemoMode.startsEmpty ? nil : { try DemoLibrary.populate($0) }
            return AppServices(
                fileStore: store,
                inMemory: true,
                session: DemoSession(playback: AudioSessionManager()),
                recorder: DemoRecorder(store: store),
                seedLibrary: seed
            )
        }
        #endif
        let fileStore = RecordingFileStore.default
        return AppServices(
            fileStore: fileStore,
            inMemory: false,
            session: AudioSessionManager(),
            recorder: AudioRecorder(
                makeTemporaryURL: { fileStore.makeTemporaryURL() },
                removeFile: { fileStore.removeTemporary(at: $0) }
            ),
            seedLibrary: nil
        )
    }
}
