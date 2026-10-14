import AppIntents
import SwiftUI
import WidgetKit

/// One tap from the Home Screen or the Lock Screen to a recording. The widget never has data to
/// refresh, so it has a single entry and no timeline.
struct RecordNoteWidget: Widget {
    static let kind = "com.cosmichomeless.murmur.record-note"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RecordNoteProvider()) { _ in
            RecordNoteWidgetView()
        }
        .configurationDisplayName("Record a note")
        .description("Start a voice note with one tap.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct RecordNoteEntry: TimelineEntry {
    let date: Date
}

struct RecordNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecordNoteEntry { RecordNoteEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (RecordNoteEntry) -> Void) {
        completion(RecordNoteEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecordNoteEntry>) -> Void) {
        completion(Timeline(entries: [RecordNoteEntry(date: .now)], policy: .never))
    }
}

struct RecordNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: RecordNoteIntent()) {
                Image(systemName: "mic.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityLabel("Record a note")
        case .accessoryRectangular:
            Button(intent: RecordNoteIntent()) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                    VStack(alignment: .leading) {
                        Text("MURMUR")
                            .font(.headline)
                        Text("Record a note")
                            .font(.caption)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .containerBackground(.fill.tertiary, for: .widget)
        default:
            Button(intent: RecordNoteIntent()) {
                VStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(WidgetBrand.coral, in: Circle())
                    Text("Record")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .containerBackground(WidgetBrand.gradient, for: .widget)
            .accessibilityLabel("Record a note")
        }
    }
}
