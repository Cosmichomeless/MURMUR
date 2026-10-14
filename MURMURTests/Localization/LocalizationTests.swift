import Foundation
import Testing
@testable import MURMUR

/// The app ships in English plus these languages. A missing or broken translation shows up as
/// English text, or worse, as a crash-prone format mismatch, so check the compiled bundle.
struct LocalizationTests {
    static let languages = ["es", "fr", "de", "it", "pt"]

    private func strings(_ language: String, table: String = "Localizable") throws -> [String: String] {
        let url = try #require(
            Bundle.main.url(forResource: table, withExtension: "strings", subdirectory: nil, localization: language)
        )
        let plist = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return plist
    }

    /// `%@`, `%lld`, `%1$@`… in the order they are used, ignoring `%%`.
    private func placeholders(in text: String) -> [String] {
        let pattern = #"%(?:\d+\$)?(?:lld|ld|d|@|f|s)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map {
            String(text[Range($0.range, in: text)!]).replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
        }
    }

    @Test(arguments: languages)
    func everyEnglishStringIsTranslated(language: String) throws {
        let english = try strings("en")
        let translated = try strings(language)
        #expect(!english.isEmpty)
        let missing = english.keys.filter { translated[$0] == nil }
        #expect(missing.isEmpty, "Missing \(language) translations: \(missing.sorted())")
    }

    @Test(arguments: languages)
    func translationsKeepTheSamePlaceholders(language: String) throws {
        let english = try strings("en")
        let translated = try strings(language)
        for (key, value) in english {
            guard let other = translated[key] else { continue }
            #expect(
                placeholders(in: value).sorted() == placeholders(in: other).sorted(),
                "\(language): placeholders differ for \"\(key)\""
            )
        }
    }

    @Test(arguments: languages)
    func permissionPromptsAreTranslated(language: String) throws {
        let table = try strings(language, table: "InfoPlist")
        for key in ["NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"] {
            let text = try #require(table[key], "\(language) lacks \(key)")
            #expect(!text.isEmpty)
        }
    }

    @Test func spanishReadsAsSpanish() throws {
        let bundle = try #require(Bundle.main.path(forResource: "es", ofType: "lproj").flatMap(Bundle.init(path:)))
        #expect(bundle.localizedString(forKey: "Settings", value: nil, table: nil) == "Ajustes")
        #expect(bundle.localizedString(forKey: "Delete", value: nil, table: nil) == "Eliminar")
    }
}
