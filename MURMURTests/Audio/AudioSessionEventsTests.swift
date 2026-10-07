import AVFoundation
import Testing
@testable import MURMUR

struct AudioSessionEventsTests {
    private func interruption(_ type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions? = nil) -> Notification {
        var info: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: type.rawValue]
        if let options { info[AVAudioSessionInterruptionOptionKey] = options.rawValue }
        return Notification(name: AVAudioSession.interruptionNotification, userInfo: info)
    }

    private func routeChange(_ reason: AVAudioSession.RouteChangeReason) -> Notification {
        Notification(
            name: AVAudioSession.routeChangeNotification,
            userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue]
        )
    }

    @Test func interruptionBeginning() {
        #expect(AudioSessionEvents.event(from: interruption(.began)) == .interruptionBegan)
    }

    @Test func interruptionEndingWithTheResumeHint() {
        let event = AudioSessionEvents.event(from: interruption(.ended, options: .shouldResume))
        #expect(event == .interruptionEnded(shouldResume: true))
    }

    @Test func interruptionEndingWithoutTheResumeHint() {
        #expect(AudioSessionEvents.event(from: interruption(.ended, options: [])) == .interruptionEnded(shouldResume: false))
        #expect(AudioSessionEvents.event(from: interruption(.ended)) == .interruptionEnded(shouldResume: false))
    }

    @Test func aMalformedInterruptionIsIgnored() {
        let notification = Notification(name: AVAudioSession.interruptionNotification, userInfo: nil)
        #expect(AudioSessionEvents.event(from: notification) == nil)
    }

    @Test func unpluggingTheDeviceLosesTheRoute() {
        #expect(AudioSessionEvents.event(from: routeChange(.oldDeviceUnavailable)) == .routeLost)
    }

    @Test func otherRouteChangesAreIgnored() {
        #expect(AudioSessionEvents.event(from: routeChange(.newDeviceAvailable)) == nil)
        #expect(AudioSessionEvents.event(from: routeChange(.categoryChange)) == nil)
        #expect(AudioSessionEvents.event(from: routeChange(.override)) == nil)
    }

    @Test func mediaServicesResetIsReported() {
        let notification = Notification(name: AVAudioSession.mediaServicesWereResetNotification)
        #expect(AudioSessionEvents.event(from: notification) == .mediaServicesReset)
    }

    @Test func unrelatedNotificationsAreIgnored() {
        #expect(AudioSessionEvents.event(from: Notification(name: .init("other"))) == nil)
    }

    @MainActor
    @Test func everySubscriberReceivesEachEvent() async {
        let center = NotificationCenter()
        let events = AudioSessionEvents(center: center)
        var first = events.subscribe().makeAsyncIterator()
        var second = events.subscribe().makeAsyncIterator()

        center.post(interruption(.began))

        #expect(await first.next() == .interruptionBegan)
        #expect(await second.next() == .interruptionBegan)
    }
}
