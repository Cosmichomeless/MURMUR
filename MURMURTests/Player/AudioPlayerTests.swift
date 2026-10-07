import AVFoundation
import Foundation
import Testing
@testable import MURMUR

@MainActor
struct AudioPlayerTests {
    /// A real, silent audio file of the given length.
    private func makeAudioFile(seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioPlayerTests-\(UUID().uuidString).wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(seconds * 8_000)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        try file.write(from: buffer)
        return url
    }

    @Test func loadsAFileAndReportsItsDuration() throws {
        let url = try makeAudioFile(seconds: 2)
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()

        try player.load(url: url)

        #expect(player.state == .paused)
        #expect(abs(player.duration - 2) < 0.05)
        #expect(player.currentTime == 0)
    }

    @Test func loadingAMissingFileThrowsAndStaysIdle() {
        let player = AudioPlayer()

        #expect(throws: AudioPlayerError.self) {
            try player.load(url: URL(fileURLWithPath: "/nonexistent/file.m4a"))
        }
        #expect(player.state == .idle)
    }

    @Test func playingWithoutAFileThrows() {
        let player = AudioPlayer()

        #expect(throws: AudioPlayerError.nothingLoaded) {
            try player.play()
        }
    }

    @Test func seekMovesThePositionAndClampsToTheDuration() throws {
        let url = try makeAudioFile(seconds: 2)
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()
        try player.load(url: url)

        player.seek(to: 1)
        #expect(abs(player.currentTime - 1) < 0.05)

        player.seek(to: 100)
        #expect(player.currentTime <= player.duration)

        player.seek(to: -3)
        #expect(player.currentTime == 0)
    }

    @Test func stopUnloads() throws {
        let url = try makeAudioFile(seconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()
        try player.load(url: url)

        player.stop()

        #expect(player.state == .idle)
        #expect(player.duration == 0)
    }

    @Test func playThenPause() throws {
        let url = try makeAudioFile(seconds: 5)
        defer { try? FileManager.default.removeItem(at: url) }
        let player = AudioPlayer()
        try player.load(url: url)

        try player.play()
        #expect(player.state == .playing)

        player.pause()
        #expect(player.state == .paused)
    }
}
