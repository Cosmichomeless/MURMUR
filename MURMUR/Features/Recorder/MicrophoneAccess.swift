import Observation

/// What the UI knows about being allowed to record, and the single gate every recording goes through.
@MainActor
@Observable
final class MicrophoneAccess {
    private(set) var permission: MicrophonePermission
    /// Set when permission was granted but the audio session could not be activated.
    private(set) var sessionError: String?

    @ObservationIgnored private let session: any AudioSessionControlling

    init(session: any AudioSessionControlling) {
        self.session = session
        self.permission = session.microphonePermission
    }

    /// Re-reads the permission. Call when the app becomes active: the user may have changed it in Settings.
    func refresh() {
        permission = session.microphonePermission
    }

    /// Resolves the permission (showing the system prompt if needed) and activates the session.
    ///
    /// Returns `true` only when it is safe to start capturing. On denial or failure nothing is
    /// started and the reason is exposed through `permission` / `sessionError`.
    func prepareForRecording() async -> Bool {
        if session.microphonePermission == .undetermined {
            permission = await session.requestMicrophonePermission()
        } else {
            refresh()
        }
        guard permission == .granted else { return false }

        do {
            try session.activateForRecording()
            sessionError = nil
            return true
        } catch {
            sessionError = error.localizedDescription
            return false
        }
    }
}
