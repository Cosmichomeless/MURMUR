import SwiftUI

@main
struct MURMURApp: App {
    @State private var microphoneAccess: MicrophoneAccess
    @State private var recorder: RecorderViewModel

    init() {
        let fileStore = RecordingFileStore.default
        try? fileStore.prepareDirectories()

        let access = MicrophoneAccess(session: AudioSessionManager())
        let audioRecorder = AudioRecorder(
            makeTemporaryURL: { fileStore.makeTemporaryURL() },
            removeFile: { fileStore.removeTemporary(at: $0) }
        )
        _microphoneAccess = State(initialValue: access)
        _recorder = State(initialValue: RecorderViewModel(
            access: access,
            recorder: audioRecorder,
            // Moves the temporary capture into the recordings folder. Metadata is added with the library.
            save: { _ = try fileStore.commit(temporaryURL: $0.fileURL) }
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(microphoneAccess: microphoneAccess, recorder: recorder)
        }
    }
}
