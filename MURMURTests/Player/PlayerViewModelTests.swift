import Foundation
import Testing
@testable import MURMUR

@MainActor
struct PlayerViewModelTests {
    private let url = URL(fileURLWithPath: "/tmp/recording.m4a")

    private func makeModel() -> (PlayerViewModel, FakeAudioPlayer, FakeAudioSession) {
        let player = FakeAudioPlayer()
        let session = FakeAudioSession(permission: .granted)
        return (PlayerViewModel(player: player, session: session), player, session)
    }

    @Test func startsIdleAndLoadsPausedAtTheBeginning() {
        let (model, player, _) = makeModel()
        #expect(model.state == .idle)

        model.load(url: url)

        #expect(model.state == .paused)
        #expect(model.currentTime == 0)
        #expect(model.duration == 10)
        #expect(player.loadedURLs == [url])
    }

    @Test func aFailedLoadSurfacesTheErrorAndStaysIdle() {
        let (model, player, _) = makeModel()
        player.loadError = AudioPlayerError.cannotLoad("missing")

        model.load(url: url)

        #expect(model.state == .idle)
        #expect(model.errorMessage != nil)
        #expect(!model.isLoaded)
    }

    @Test func playActivatesThePlaybackSession() {
        let (model, _, session) = makeModel()
        model.load(url: url)

        model.play()

        #expect(model.state == .playing)
        #expect(session.playbackActivations == 1)
    }

    @Test func playDoesNothingWithoutALoadedRecording() {
        let (model, _, session) = makeModel()

        model.play()

        #expect(model.state == .idle)
        #expect(session.playbackActivations == 0)
    }

    @Test func togglePlaysThenPauses() {
        let (model, _, _) = makeModel()
        model.load(url: url)

        model.togglePlayPause()
        #expect(model.state == .playing)

        model.togglePlayPause()
        #expect(model.state == .paused)
    }

    @Test func pauseKeepsThePositionAndTheSession() {
        let (model, player, session) = makeModel()
        model.load(url: url)
        model.play()
        player.advance(to: 4)
        model.tick()

        model.pause()

        #expect(model.state == .paused)
        #expect(model.currentTime == 4)
        #expect(session.deactivations == 0)
    }

    @Test func tickPublishesTheProgress() {
        let (model, player, _) = makeModel()
        model.load(url: url)
        model.play()

        player.advance(to: 2.5)
        model.tick()

        #expect(model.currentTime == 2.5)
        #expect(model.progress == 0.25)
    }

    @Test func seekMovesThePositionWithoutChangingTheState() {
        let (model, _, _) = makeModel()
        model.load(url: url)

        model.seek(to: 7)
        #expect(model.currentTime == 7)
        #expect(model.state == .paused)

        model.play()
        model.seek(to: 3)
        #expect(model.currentTime == 3)
        #expect(model.state == .playing)
    }

    @Test func seekIsClampedToTheRecording() {
        let (model, _, _) = makeModel()
        model.load(url: url)

        model.seek(to: 99)
        #expect(model.currentTime == 10)

        model.seek(to: -5)
        #expect(model.currentTime == 0)
    }

    @Test func reachingTheEndFinishesAndReleasesTheSession() {
        let (model, player, session) = makeModel()
        model.load(url: url)
        model.play()

        player.reachTheEnd()
        model.tick()

        #expect(model.state == .finished)
        #expect(model.currentTime == 10)
        #expect(model.progress == 1)
        #expect(session.deactivations == 1)
    }

    @Test func playingAgainAfterTheEndRestartsFromTheBeginning() {
        let (model, player, session) = makeModel()
        model.load(url: url)
        model.play()
        player.reachTheEnd()
        model.tick()

        model.togglePlayPause()

        #expect(model.state == .playing)
        #expect(model.currentTime == 0)
        #expect(session.playbackActivations == 2)
    }

    @Test func seekingAfterTheEndMakesItPlayableFromThere() {
        let (model, player, _) = makeModel()
        model.load(url: url)
        model.play()
        player.reachTheEnd()
        model.tick()

        model.seek(to: 2)

        #expect(model.state == .paused)
        #expect(model.currentTime == 2)
    }

    @Test func aPlaybackFailureIsReportedAndReleasesTheSession() {
        let (model, player, session) = makeModel()
        model.load(url: url)
        player.playError = AudioPlayerError.cannotPlay

        model.play()

        #expect(model.state == .paused)
        #expect(model.errorMessage != nil)
        #expect(session.deactivations == 1)
    }

    @Test func stopUnloadsAndReleasesTheSession() {
        let (model, _, session) = makeModel()
        model.load(url: url)
        model.play()

        model.stop()

        #expect(model.state == .idle)
        #expect(model.currentTime == 0)
        #expect(model.duration == 0)
        #expect(session.deactivations == 1)
    }

    @Test func stopWhenNothingIsLoadedLeavesTheSessionAlone() {
        let (model, _, session) = makeModel()

        model.stop()

        #expect(session.deactivations == 0)
    }

    @Test func loadingAnotherRecordingReplacesTheCurrentOne() {
        let (model, player, _) = makeModel()
        model.load(url: url)
        model.play()
        player.advance(to: 5)
        model.tick()

        model.load(url: URL(fileURLWithPath: "/tmp/other.m4a"))

        #expect(model.state == .paused)
        #expect(model.currentTime == 0)
        #expect(player.loadedURLs.count == 2)
    }
}
