import Testing
@testable import MURMUR

struct TagListTests {
    @Test func inputIsSplitOnCommasSemicolonsAndLineBreaks() {
        #expect(TagList.parse("work, ideas;trip\nhome") == ["work", "ideas", "trip", "home"])
    }

    @Test func hashesAndExtraSpacesAreRemoved() {
        #expect(TagList.parse("  ##deep   work ,#idea") == ["deep work", "idea"])
    }

    @Test func tagsDifferingInCaseOrAccentsAreOneTagAndTheFirstSpellingWins() {
        #expect(TagList.normalize(["Café", "cafe", "CAFÉ", "tea"]) == ["Café", "tea"])
    }

    @Test func emptyPiecesAreDropped() {
        #expect(TagList.parse(" , ,#, ") == [])
    }

    @Test func aLongTagIsCutAndTheListIsCapped() {
        let long = String(repeating: "a", count: 80)
        #expect(TagList.parse(long).first?.count == TagList.maxLength)

        let many = (1...25).map { "tag\($0)" }
        #expect(TagList.normalize(many).count == TagList.maxTags)
    }

    @Test func storingAndReadingGivesTheSameTags() {
        let tags = ["work", "deep work", "ñandú"]
        #expect(TagList.decode(TagList.encode(tags)) == tags)
        #expect(TagList.decode("") == [])
    }
}
