import Testing
@testable import MURMUR

struct DurationFormatTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(DurationFormat.clock(0) == "0:00")
        #expect(DurationFormat.clock(5.9) == "0:05")
        #expect(DurationFormat.clock(65) == "1:05")
        #expect(DurationFormat.clock(600) == "10:00")
    }

    @Test func showsHoursFromOneHour() {
        #expect(DurationFormat.clock(3600) == "1:00:00")
        #expect(DurationFormat.clock(3725) == "1:02:05")
    }

    @Test func negativeValuesClampToZero() {
        #expect(DurationFormat.clock(-3) == "0:00")
    }
}
