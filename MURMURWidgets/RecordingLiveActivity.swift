import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The recording in progress, on the Lock Screen and in the Dynamic Island: the time and a stop button.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            HStack(spacing: 16) {
                StatusGlyph(state: context.state)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.isPaused ? "Paused" : "Recording")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    ActivityClock(state: context.state)
                        .font(.system(.title, design: .monospaced).weight(.light))
                }
                Spacer(minLength: 0)
                StopButton()
            }
            .foregroundStyle(.white)
            .padding()
            .activityBackgroundTint(WidgetBrand.violetDeep)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusGlyph(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ActivityClock(state: context.state)
                        .font(.system(.title2, design: .monospaced).weight(.light))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StopButton()
                }
            } compactLeading: {
                StatusGlyph(state: context.state)
            } compactTrailing: {
                ActivityClock(state: context.state)
                    .font(.caption.monospacedDigit())
                    .frame(width: 52)
            } minimal: {
                StatusGlyph(state: context.state)
            }
            .keylineTint(WidgetBrand.coral)
        }
    }
}

/// The time on the clock. While recording the system counts from `clockStart`, so the app does not
/// have to push an update every second; while paused it holds still at the elapsed time.
private struct ActivityClock: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        Group {
            if let start = state.clockStart {
                Text(start, style: .timer)
            } else {
                let now = Date.now
                Text(
                    timerInterval: now.addingTimeInterval(-state.elapsed)...now.addingTimeInterval(86_400),
                    pauseTime: now,
                    countsDown: false
                )
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.leading)
    }
}

private struct StatusGlyph: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.isPaused ? "pause.fill" : "waveform")
            .font(.title3)
            .foregroundStyle(WidgetBrand.coral)
            .symbolEffect(.variableColor.iterative, isActive: !state.isPaused)
            .accessibilityLabel(state.isPaused ? "Paused" : "Recording")
    }
}

private struct StopButton: View {
    var body: some View {
        Button(intent: StopRecordingIntent()) {
            Image(systemName: "stop.fill")
                .font(.title3)
                .foregroundStyle(WidgetBrand.violetDeep)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop and save")
    }
}
