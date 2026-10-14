import SwiftUI
import WidgetKit

/// Everything MURMUR puts outside the app: a widget for the Home and Lock Screen, a control for
/// Control Center and the Action Button, and the Live Activity of a recording in progress.
@main
struct MURMURWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecordNoteWidget()
        RecordingLiveActivity()
        if #available(iOS 18.0, *) {
            RecordNoteControl()
        }
    }
}
