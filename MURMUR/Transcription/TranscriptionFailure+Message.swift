import Foundation

extension TranscriptionFailure {
    /// Plain words for the person looking at the note. Resolved when shown, so it follows the app's language.
    var message: String {
        switch self {
        case .notAuthorized:
            String(localized: "Speech recognition is turned off for MURMUR. Allow it in Settings to get a transcript.")
        case .languageUnsupported:
            String(localized: "This language can't be transcribed on this device. Pick another one in MURMUR's settings.")
        case .onDeviceUnavailable:
            String(localized: "This language isn't available for on-device transcription. Your audio is never sent to a server, so there is no fallback.")
        case .noSpeech:
            String(localized: "No speech was found in this recording.")
        case .failed:
            String(localized: "The transcription didn't work. Try again.")
        }
    }
}
