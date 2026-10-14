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
    let speech: any SpeechEngine
    /// The Live Activity of a recording in progress.
    let activity: (any RecordingActivityControlling)?
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
                speech: DemoSpeechEngine(),
                activity: RecordingActivityController(),
                seedLibrary: seed
            )
        }
        #endif
        let fileStore = RecordingFileStore.default
        // The unit tests run inside the app: ActivityKit has nothing to show there (and can stall on a
        // headless CI machine), and the recorder tests use their own fake.
        let underTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        return AppServices(
            fileStore: fileStore,
            inMemory: false,
            session: AudioSessionManager(),
            recorder: AudioRecorder(
                makeTemporaryURL: { fileStore.makeTemporaryURL() },
                removeFile: { fileStore.removeTemporary(at: $0) }
            ),
            speech: AppleSpeechEngine(),
            activity: underTest ? nil : RecordingActivityController(),
            seedLibrary: nil
        )
    }
}
