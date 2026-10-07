import SwiftUI

/// Temporary shell. Replaced by the Library screen when recordings are listed.
struct RootView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RecorderView(model: recorder, access: microphoneAccess)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    microphoneAccess.refresh()
                }
            }
    }
}
