import Foundation
@testable import MURMUR

/// Lets a test play the part of the system: `send` reaches every subscriber.
@MainActor
final class FakeAudioSessionEvents: AudioSessionEventSource {
    private var continuations: [AsyncStream<AudioSessionEvent>.Continuation] = []

    func subscribe() -> AsyncStream<AudioSessionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: AudioSessionEvent.self)
        continuations.append(continuation)
        return stream
    }

    func send(_ event: AudioSessionEvent) {
        for continuation in continuations { continuation.yield(event) }
    }
}
