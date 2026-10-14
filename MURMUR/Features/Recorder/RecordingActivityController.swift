import ActivityKit
import Foundation

/// What the recorder tells the Live Activity. A seam so the recorder can be tested without ActivityKit.
@MainActor
protocol RecordingActivityControlling: AnyObject {
    func recordingStarted()
    func recordingPaused(elapsed: TimeInterval)
    func recordingResumed(elapsed: TimeInterval)
    func recordingEnded()
}

/// `Activity` is not marked `Sendable`, but ActivityKit documents its updates as safe to make from any
/// task. The box lets them leave the main actor.
private struct ActivityBox: @unchecked Sendable {
    let activity: Activity<RecordingActivityAttributes>
}

/// Shows the recording in progress on the Lock Screen and in the Dynamic Island.
///
/// The activity counts the time by itself from a start date, so it is only updated when the state
/// changes (pause, resume), not every second. If the user has turned Live Activities off, or the
/// request fails, recording goes on without it.
@MainActor
final class RecordingActivityController: RecordingActivityControlling {
    private var activity: Activity<RecordingActivityAttributes>?
    /// Updates and the end go through one chain so they reach the system in the order they happened.
    private var chain: Task<Void, Never>?

    init() {
        endLeftovers()
    }

    func recordingStarted() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: RecordingActivityAttributes.ContentState.recording(elapsed: 0), staleDate: nil)
        activity = try? Activity.request(attributes: RecordingActivityAttributes(), content: content)
    }

    func recordingPaused(elapsed: TimeInterval) {
        push(.paused(elapsed: elapsed))
    }

    func recordingResumed(elapsed: TimeInterval) {
        push(.recording(elapsed: elapsed))
    }

    func recordingEnded() {
        guard let activity else { return }
        self.activity = nil
        let box = ActivityBox(activity: activity)
        enqueue { await box.activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Private

    private func push(_ state: RecordingActivityAttributes.ContentState) {
        guard let activity else { return }
        let box = ActivityBox(activity: activity)
        enqueue { await box.activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = chain
        chain = Task {
            await previous?.value
            await work()
        }
    }

    /// An activity that outlived the process (a crash or a kill mid-recording) would show a clock
    /// that keeps counting for a recording that no longer exists.
    private func endLeftovers() {
        let leftovers = Activity<RecordingActivityAttributes>.activities
        guard !leftovers.isEmpty else { return }
        let boxes = leftovers.map { ActivityBox(activity: $0) }
        enqueue {
            for box in boxes {
                await box.activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
