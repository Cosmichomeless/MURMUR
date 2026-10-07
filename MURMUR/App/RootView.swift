import SwiftUI

/// Temporary shell. Replaced by the Library screen when recordings are listed.
struct RootView: View {
    let microphoneAccess: MicrophoneAccess
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MicrophonePermissionView(access: microphoneAccess)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    microphoneAccess.refresh()
                }
            }
    }
}
