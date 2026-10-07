import AVFoundation

/// Turns `AVAudioSession` notifications into `AudioSessionEvent`s and fans them out to subscribers.
@MainActor
final class AudioSessionEvents: AudioSessionEventSource {
    private var continuations: [UUID: AsyncStream<AudioSessionEvent>.Continuation] = [:]
    // Observers live as long as the app: this is created once at launch.
    private var observers: [any NSObjectProtocol] = []

    init(center: NotificationCenter = .default) {
        let names = [
            AVAudioSession.interruptionNotification,
            AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereResetNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let event = Self.event(from: notification) else { return }
                Task { @MainActor in self?.publish(event) }
            }
        }
    }

    func subscribe() -> AsyncStream<AudioSessionEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: AudioSessionEvent.self)
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    private func publish(_ event: AudioSessionEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Pure, so tests can feed it hand-made notifications.
    nonisolated static func event(from notification: Notification) -> AudioSessionEvent? {
        let info = notification.userInfo
        switch notification.name {
        case AVAudioSession.interruptionNotification:
            guard let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return nil }
            switch type {
            case .began:
                return .interruptionBegan
            case .ended:
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                )
                return .interruptionEnded(shouldResume: options.contains(.shouldResume))
            @unknown default:
                return nil
            }

        case AVAudioSession.routeChangeNotification:
            // Only a device going away matters; a new one appearing needs no reaction.
            guard let raw = info?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
            else { return nil }
            return .routeLost

        case AVAudioSession.mediaServicesWereResetNotification:
            return .mediaServicesReset

        default:
            return nil
        }
    }
}
