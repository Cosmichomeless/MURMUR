import SwiftUI

struct RootView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel
    let repository: RecordingRepository
    let player: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TranscriptionService.self) private var transcription

    var body: some View {
        LibraryView(
            microphoneAccess: microphoneAccess,
            recorder: recorder,
            repository: repository,
            player: player
        )
            .task { transcription.resumePending() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    microphoneAccess.refresh()
                    recorder.permissionDidChange()
                    transcription.resumePending()
                }
            }
    }
}
