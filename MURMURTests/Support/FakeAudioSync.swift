import Foundation
@testable import MURMUR

/// Records what the repository tells the audio sync.
final class FakeAudioSync: AudioSyncing, @unchecked Sendable {
    enum Call: Equatable {
        case added(String)
        case removed(String)
    }

    private let lock = NSLock()
    private var recorded: [Call] = []

    var calls: [Call] { lock.withLock { recorded } }

    func audioAdded(fileName: String) { lock.withLock { recorded.append(.added(fileName)) } }
    func audioRemoved(fileName: String) { lock.withLock { recorded.append(.removed(fileName)) } }
}
