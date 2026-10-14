import Foundation
@testable import MURMUR

@MainActor
final class FakeRecordingActivity: RecordingActivityControlling {
    enum Call: Equatable {
        case started
        case paused(TimeInterval)
        case resumed(TimeInterval)
        case ended
    }

    private(set) var calls: [Call] = []

    func recordingStarted() { calls.append(.started) }
    func recordingPaused(elapsed: TimeInterval) { calls.append(.paused(elapsed)) }
    func recordingResumed(elapsed: TimeInterval) { calls.append(.resumed(elapsed)) }
    func recordingEnded() { calls.append(.ended) }
}
