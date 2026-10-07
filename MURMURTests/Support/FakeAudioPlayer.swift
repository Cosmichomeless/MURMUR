import Foundation
@testable import MURMUR

@MainActor
final class FakeAudioPlayer: AudioPlaying {
    var loadError: (any Error)?
    var playError: (any Error)?
    var loadedDuration: TimeInterval = 10

    private(set) var state: PlayerState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var loadedURLs: [URL] = []
    private(set) var stopCount = 0

    func load(url: URL) throws {
        if let loadError { throw loadError }
        loadedURLs.append(url)
        duration = loadedDuration
        currentTime = 0
        state = .paused
    }

    func play() throws {
        if let playError { throw playError }
        if state == .finished { currentTime = 0 }
        state = .playing
    }

    func pause() {
        if state == .playing { state = .paused }
    }

    func seek(to time: TimeInterval) {
        currentTime = min(max(time, 0), duration)
        if state == .finished { state = .paused }
    }

    func stop() {
        stopCount += 1
        state = .idle
        currentTime = 0
        duration = 0
    }

    // Test controls

    func advance(to time: TimeInterval) {
        currentTime = time
    }

    func reachTheEnd() {
        currentTime = duration
        state = .finished
    }
}
