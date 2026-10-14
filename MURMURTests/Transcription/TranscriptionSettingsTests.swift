import Foundation
import Testing
@testable import MURMUR

@MainActor
struct TranscriptionSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let name = "MURMURTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func locales(_ identifiers: String...) -> [Locale] { identifiers.map(Locale.init(identifier:)) }

    @Test func defaultsAreAutomaticLanguageAndAutoTranscribeOn() {
        let settings = TranscriptionSettings(defaults: makeDefaults())
        #expect(settings.languageIdentifier == nil)
        #expect(settings.autoTranscribe)
    }

    @Test func choicesSurviveARelaunch() {
        let defaults = makeDefaults()
        let first = TranscriptionSettings(defaults: defaults)
        first.languageIdentifier = "es-ES"
        first.autoTranscribe = false

        let second = TranscriptionSettings(defaults: defaults)
        #expect(second.languageIdentifier == "es-ES")
        #expect(!second.autoTranscribe)

        second.languageIdentifier = nil
        #expect(TranscriptionSettings(defaults: defaults).languageIdentifier == nil)
    }

    @Test func aChosenLanguageWinsOverTheDevice() {
        let settings = TranscriptionSettings(defaults: makeDefaults())
        settings.languageIdentifier = "es-ES"
        let resolved = settings.resolveLocale(
            supported: locales("en-US", "es-ES"),
            preferredLanguages: ["en-US"]
        )
        #expect(resolved?.identifier(.bcp47) == "es-ES")
    }

    @Test func automaticFollowsTheDeviceLanguagesInOrder() {
        let settings = TranscriptionSettings(defaults: makeDefaults())
        let resolved = settings.resolveLocale(
            supported: locales("en-US", "de-DE"),
            preferredLanguages: ["fr-FR", "de-AT", "en-US"]
        )
        // French is not available; German in another region is the next best thing.
        #expect(resolved?.identifier(.bcp47) == "de-DE")
    }

    @Test func aRegionThatHasNoModelFallsBackToTheSameLanguage() {
        let match = TranscriptionSettings.match(identifier: "es-MX", in: locales("en-US", "es-ES"))
        #expect(match?.language.languageCode?.identifier == "es")
    }

    @Test func nothingMatchesWhenTheLanguageIsMissing() {
        let settings = TranscriptionSettings(defaults: makeDefaults())
        #expect(settings.resolveLocale(supported: locales("en-US"), preferredLanguages: ["ja-JP"]) == nil)
        settings.languageIdentifier = "ja-JP"
        #expect(settings.resolveLocale(supported: locales("en-US"), preferredLanguages: ["en-US"]) == nil)
    }
}
