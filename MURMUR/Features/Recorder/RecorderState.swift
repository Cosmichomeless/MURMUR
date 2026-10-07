enum RecorderState: Equatable {
    case idle
    case recording
    case paused
    case failed(String)

    enum Event: Equatable {
        case start
        case pause
        case resume
        case stop
        case discard
        case fail(String)
        case dismissFailure
    }

    /// The state after `event`, or `nil` when the event is not valid here.
    func applying(_ event: Event) -> RecorderState? {
        switch (self, event) {
        case (.idle, .start): .recording
        case (.recording, .pause): .paused
        case (.paused, .resume): .recording
        case (.recording, .stop), (.paused, .stop): .idle
        case (.recording, .discard), (.paused, .discard): .idle
        case (.recording, .fail(let message)), (.paused, .fail(let message)), (.idle, .fail(let message)):
            .failed(message)
        case (.failed, .dismissFailure): .idle
        case (.failed, .start): .recording
        default: nil
        }
    }

    var isCapturing: Bool {
        switch self {
        case .recording, .paused: true
        case .idle, .failed: false
        }
    }
}
