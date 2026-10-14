import AppIntents
import SwiftUI
import WidgetKit

/// The control for Control Center, the Lock Screen and the Action Button (iOS 18 and later).
@available(iOS 18.0, *)
struct RecordNoteControl: ControlWidget {
    static let kind = "com.cosmichomeless.murmur.record-note-control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: RecordNoteIntent()) {
                Label("Record a note", systemImage: "mic.fill")
            }
        }
        .displayName("Record a note")
        .description("Start a voice note with one tap.")
    }
}
