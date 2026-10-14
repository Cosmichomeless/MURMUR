import AppIntents

/// «Record a note»: Shortcuts, the Action Button, Control Center, the Lock Screen and the widgets.
///
/// It opens the app because capture needs the microphone session of the app itself.
struct RecordNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a note"
    static let description = IntentDescription("Starts recording a voice note in MURMUR.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickCaptureCoordinator.shared.send(.start)
        return .result()
    }
}

/// The stop button of the Live Activity. It runs in the app, which is alive because it is recording.
struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop and save"
    static let description = IntentDescription("Stops the recording in progress and saves it.")

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickCaptureCoordinator.shared.send(.stop)
        return .result()
    }
}
