import Testing
@testable import MURMUR

struct ProjectSmokeTests {
    @Test func microphonePermissionCasesAreDistinct() {
        #expect(MicrophonePermission.undetermined != .granted)
        #expect(MicrophonePermission.granted != .denied)
    }

    @Test func recorderSampleIsEquatable() {
        #expect(RecorderSample(level: 0.5, duration: 1) == RecorderSample(level: 0.5, duration: 1))
    }
}
