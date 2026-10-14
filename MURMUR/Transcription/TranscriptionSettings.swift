import Foundation
import Observation

/// What the user chose about transcription: the language and whether it starts by itself.
///
/// Stored in `UserDefaults` (declared in the privacy manifest as the app's own preferences).
@MainActor
@Observable
final class TranscriptionSettings {
    static let languageKey = "transcription.language"
    static let autoTranscribeKey = "transcription.auto"

    /// The chosen language, or `nil` to follow the device's languages.
    var languageIdentifier: String? {
        didSet { defaults.set(languageIdentifier, forKey: Self.languageKey) }
    }

    /// Transcribe each recording as soon as it is saved. On by default.
    var autoTranscribe: Bool {
        didSet { defaults.set(autoTranscribe, forKey: Self.autoTranscribeKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        languageIdentifier = defaults.string(forKey: Self.languageKey)
        autoTranscribe = defaults.object(forKey: Self.autoTranscribeKey) as? Bool ?? true
    }

    /// The language to transcribe in, among the ones the device can do. `nil` if none fits.
    ///
    /// A chosen language wins when it is available. Otherwise (automatic) the device's preferred
    /// languages are tried in order, preferring the same region and then any region of the language.
    func resolveLocale(
        supported: [Locale],
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale? {
        if let languageIdentifier {
            return Self.match(identifier: languageIdentifier, in: supported)
        }
        for identifier in preferredLanguages {
            if let match = Self.match(identifier: identifier, in: supported) { return match }
        }
        return nil
    }

    /// An exact match, else the same language in the same region, else any region of that language.
    static func match(identifier: String, in supported: [Locale]) -> Locale? {
        let wanted = Locale(identifier: identifier)
        if let exact = supported.first(where: { $0.identifier(.bcp47) == wanted.identifier(.bcp47) }) { return exact }
        guard let language = wanted.language.languageCode else { return nil }
        let sameLanguage = supported.filter { $0.language.languageCode == language }
        if let region = wanted.region,
           let sameRegion = sameLanguage.first(where: { $0.region == region }) {
            return sameRegion
        }
        // Prefer the language's own region when the device's region has no model (es-US → es-ES).
        return sameLanguage.first { $0.region == Locale.current.region } ?? sameLanguage.first
    }
}
