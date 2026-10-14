# App Review and App Store Connect: answers to enter

Everything here is **prepared text, not submitted**. Entering it in App Store Connect is a separate step that needs the developer's explicit go-ahead for each item.

## Review notes (paste in "Notes")

MURMUR is a voice-note recorder. It needs no account or sign-in.

- **Microphone:** used to record voice notes when the user taps Record.
- **Background audio (`UIBackgroundModes: audio`):** a recording that is in progress must not stop when the user locks the phone or switches app: a voice memo that silently stops after a few seconds in the background would lose what the user was saying. The mode is used only while a recording or playback is active; the app plays and records nothing otherwise.
- **Speech recognition:** optional. Notes are transcribed with Apple's Speech framework with `requiresOnDeviceRecognition = true`, so audio never leaves the device. If the language has no on-device model, the app says so and does not transcribe.
- **No network use:** the app makes no network requests and includes no third-party SDKs. The privacy policy and support links open in Safari.
- To test quickly: tap the microphone, say a sentence, tap Stop. The note appears in the library; open it to play it and read the transcript (allow Speech Recognition when asked).

## App Privacy ("nutrition label")

Answer: **Data Not Collected.** Nothing is sent off the device, there are no analytics, ads or SDKs, so no data type applies and nothing is used for tracking. This matches `MURMUR/PrivacyInfo.xcprivacy` (`NSPrivacyTracking = false`, no collected data types, one required-reason API: UserDefaults `CA92.1`, used for the transcription language setting).

Privacy policy URL: `https://github.com/Cosmichomeless/MURMUR/blob/main/docs/privacy.md` (published once these docs are on `main`).

## Support URL

`https://github.com/Cosmichomeless/MURMUR/blob/main/docs/support.md` (the same condition applies).

## Age rating

Every content question: **None**. User-generated content, unrestricted web access, messaging and in-app purchases: **No**. Expected rating: **4+**.

## EU Digital Services Act (trader status)

This one is the developer's decision, not a technical one: Apple asks whether the app is offered *as a trader* (acting for business or professional purposes) or not. A free app made as a hobby may be a non-trader; selling it, or publishing it as a business, makes the developer a trader and then name, address, phone and email are shown publicly on the EU listing. Without a declaration the app is not distributed in the EU.

## Localized listing

See [app-store-listing.md](app-store-listing.md).
