import Testing
@testable import MURMUR

/// Every (state, event) pair, written out. A new state or event breaks the build of this table,
/// so a transition can't be added without deciding whether it is valid.
struct RecorderStateMachineTests {
    private typealias Event = RecorderState.Event

    private static let states: [RecorderState] = [.idle, .recording, .paused, .failed("x")]
    private static let events: [Event] = [.start, .pause, .resume, .stop, .discard, .fail("e"), .dismissFailure]

    /// Rows follow `states`, columns follow `events`. `nil` means the event is rejected.
    private static let expected: [[RecorderState?]] = [
        //            start        pause   resume       stop   discard  fail           dismiss
        /* idle      */ [.recording, nil,    nil,         nil,   nil,     .failed("e"),  nil],
        /* recording */ [nil,        .paused, nil,        .idle, .idle,   .failed("e"),  nil],
        /* paused    */ [nil,        nil,    .recording,  .idle, .idle,   .failed("e"),  nil],
        /* failed    */ [.recording, nil,    nil,         nil,   nil,     nil,           .idle],
    ]

    @Test func everyTransitionMatchesTheTable() {
        for (row, state) in Self.states.enumerated() {
            for (column, event) in Self.events.enumerated() {
                #expect(
                    state.applying(event) == Self.expected[row][column],
                    "\(state) + \(event)"
                )
            }
        }
    }

    @Test func aFailureIsOnlyEverReachedThroughAFailEvent() {
        for state in Self.states {
            for event in Self.events {
                guard case .failed? = state.applying(event) else { continue }
                if case .fail = event { continue }
                if case .failed = state { continue }
                Issue.record("\(state) + \(event) produced a failure without a .fail event")
            }
        }
    }

    @Test func randomEventSequencesNeverLeaveTheValidStates() {
        var generator = SeededGenerator(seed: 7)
        var state = RecorderState.idle
        var accepted = 0

        for _ in 0..<20_000 {
            let event = Self.events.randomElement(using: &generator)!
            guard let next = state.applying(event) else { continue }
            accepted += 1
            state = next

            // Capturing means a file is open: it is exactly recording or paused.
            switch state {
            case .recording, .paused: #expect(state.isCapturing)
            case .idle, .failed: #expect(!state.isCapturing)
            }
        }
        #expect(accepted > 1_000) // the walk really exercised the machine
    }
}
