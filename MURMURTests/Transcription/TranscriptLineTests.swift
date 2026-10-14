import Foundation
import Testing
@testable import MURMUR

struct TranscriptLineTests {
    private func word(_ text: String, at start: TimeInterval, length: TimeInterval = 0.3) -> TranscriptSegment {
        TranscriptSegment(text: text, start: start, duration: length)
    }

    @Test func aPauseStartsANewLine() {
        let lines = TranscriptLine.lines(from: [
            word("Good", at: 0), word("morning", at: 0.4),
            word("Today", at: 3.0), word("we", at: 3.4), word("ship", at: 3.8),
        ])
        #expect(lines.map(\.text) == ["Good morning", "Today we ship"])
        #expect(lines.map(\.start) == [0, 3.0])
        #expect(lines.map(\.id) == [0, 1])
    }

    @Test func aLongRunIsSplitEvenWithoutPauses() {
        let segments = (0..<30).map { word("w\($0)", at: Double($0) * 0.35) }
        let lines = TranscriptLine.lines(from: segments, maxWords: 10)
        #expect(lines.count == 3)
        #expect(lines.allSatisfy { $0.text.split(separator: " ").count == 10 })
    }

    @Test func blankSegmentsAreIgnoredAndNothingMakesNoLines() {
        #expect(TranscriptLine.lines(from: []).isEmpty)
        #expect(TranscriptLine.lines(from: [word("  ", at: 0), word("", at: 1)]).isEmpty)
    }

    @Test func languagesWithoutSpacesJoinWithoutSeparator() {
        let segments = [word("今日", at: 0), word("は", at: 0.3), word("晴れ", at: 0.6)]
        let separator = TranscriptLine.separator(forLocaleIdentifier: "ja-JP")
        #expect(separator == "")
        #expect(TranscriptLine.lines(from: segments, separator: separator).first?.text == "今日は晴れ")
        #expect(TranscriptLine.separator(forLocaleIdentifier: "es-ES") == " ")
        #expect(TranscriptLine.separator(forLocaleIdentifier: nil) == " ")
    }

    @Test func segmentsRoundTripThroughTheirCodec() {
        let segments = [word("a", at: 0), word("b", at: 1.5, length: 0.25)]
        #expect(TranscriptSegmentCodec.decode(TranscriptSegmentCodec.encode(segments)) == segments)
        #expect(TranscriptSegmentCodec.encode([]) == nil)
        #expect(TranscriptSegmentCodec.decode(nil).isEmpty)
        #expect(TranscriptSegmentCodec.decode(Data([0, 1, 2])).isEmpty)
    }
}
