import Foundation

/// What the widgets, the Action Button, Shortcuts and the Live Activity ask the app to do.
enum QuickCaptureCommand: Sendable, Equatable {
    case start
    case stop
}

/// The single door from outside the app (App Intents) into the recorder.
///
/// An intent can run before the app has finished launching, so a command that arrives with nobody
/// listening is kept and delivered when the app attaches. This file is compiled into the app and
/// into the widgets extension, so it must not depend on anything else of the app.
@MainActor
final class QuickCaptureCoordinator {
    static let shared = QuickCaptureCoordinator()

    typealias Handler = @MainActor (QuickCaptureCommand, ContinuousClock.Instant) -> Void

    /// A command that nobody picked up for this long is not what the user wants any more.
    static let staleAfter: Duration = .seconds(15)

    private var handler: Handler?
    private var pending: [(command: QuickCaptureCommand, at: ContinuousClock.Instant)] = []

    /// - Parameter instant: When the user asked. The recorder measures the time to the first audio from it.
    func send(_ command: QuickCaptureCommand, at instant: ContinuousClock.Instant = .now) {
        if let handler {
            handler(command, instant)
        } else {
            pending.append((command, instant))
        }
    }

    /// Starts delivering commands, including the ones that arrived before.
    func attach(_ handler: @escaping Handler) {
        self.handler = handler
        let queued = pending
        pending = []
        for item in queued where item.at.duration(to: .now) <= Self.staleAfter {
            handler(item.command, item.at)
        }
    }

    func detach() {
        handler = nil
    }
}
