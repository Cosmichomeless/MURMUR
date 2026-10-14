import AppIntents

/// Makes «Record a note» appear in Shortcuts and Spotlight without the user setting anything up,
/// and available to the Action Button.
struct MURMURShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordNoteIntent(),
            phrases: [
                "Record a note in \(.applicationName)",
                "Start recording in \(.applicationName)",
            ],
            shortTitle: "Record a note",
            systemImageName: "mic.fill"
        )
    }
}
