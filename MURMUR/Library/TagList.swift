import Foundation

/// Turns what the user typed into a clean list of tags, and stores that list as one string.
///
/// A tag is a short word or phrase without `#` or line breaks. Two tags that differ only in case
/// or accents are the same tag; the first spelling wins.
enum TagList {
    static let maxTags = 10
    static let maxLength = 30

    /// Splits free text on commas and line breaks and cleans every piece.
    static func parse(_ input: String) -> [String] {
        normalize(input.components(separatedBy: CharacterSet(charactersIn: ",;\n")))
    }

    /// Cleans, de-duplicates and limits a list of candidate tags.
    static func normalize(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        var tags: [String] = []
        for candidate in candidates {
            let tag = clean(candidate)
            guard !tag.isEmpty, seen.insert(key(tag)).inserted else { continue }
            tags.append(tag)
            if tags.count == maxTags { break }
        }
        return tags
    }

    /// The form two tags are compared in.
    static func key(_ tag: String) -> String {
        tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func encode(_ tags: [String]) -> String {
        normalize(tags).joined(separator: "\n")
    }

    static func decode(_ raw: String) -> [String] {
        raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private static func clean(_ candidate: String) -> String {
        var text = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasPrefix("#") { text.removeFirst() }
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(text.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }
}
