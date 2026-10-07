import Testing
@testable import MURMUR

struct LevelMeterTests {
    @Test func silenceMapsToZero() {
        #expect(LevelMeter.normalizedLevel(fromRMS: 0) == 0)
        #expect(LevelMeter.normalizedLevel(fromRMS: 0.0001) == 0) // below -60 dB
    }

    @Test func fullScaleMapsToOne() {
        #expect(LevelMeter.normalizedLevel(fromRMS: 1) == 1)
        #expect(LevelMeter.normalizedLevel(fromRMS: 4) == 1) // clamped
    }

    @Test func halfAmplitudeIsAboutMinusSixDecibels() {
        let level = LevelMeter.normalizedLevel(fromRMS: 0.5)
        #expect(abs(level - 0.9) < 0.01)
    }

    @Test func levelGrowsWithAmplitude() {
        let quiet = LevelMeter.normalizedLevel(fromRMS: 0.01)
        let loud = LevelMeter.normalizedLevel(fromRMS: 0.2)
        #expect(quiet < loud)
    }
}
