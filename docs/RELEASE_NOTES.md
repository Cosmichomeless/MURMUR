# Release notes

## 1.0.0 — Search, share, transcribe, localized

Everything in 0.1.0, plus the features needed to make a voice note worth keeping. This is the
version prepared for TestFlight and App Store review.

### What is new

- **Transcription on the device.** Notes are transcribed with the Speech framework, requiring
  on-device recognition so audio and text never leave the phone. iOS 26 uses `SpeechAnalyzer`;
  earlier versions use `SFSpeechRecognizer`.
- **Rename, tag and search.** Rename notes, add tags, and search titles, tags and transcripts, jumping
  to the matching moment of the recording. Adds schema V3 to the SwiftData store.
- **Share and export.** Share the audio (`.m4a`) or the transcript (`.txt` / `.md`) from the player,
  and several notes at once from the library in selection mode.
- **Spanish, French, German, Italian and Portuguese.** All interface strings and permission prompts
  are in a String Catalog.
- **App Review material.** Privacy manifest, privacy policy and support page, review notes in
  [APP_REVIEW.md](APP_REVIEW.md) and the store text in [app-store-listing.md](app-store-listing.md).

### Known limits

- Transcription has only been tested with a fake engine. Accuracy and speed on real audio in Spanish
  and English are **not** measured.
- The new screens (rename, tags, search, share, selection mode) and the translated interface have not
  been reviewed visually on a device. The translations have not been reviewed by native speakers.
- The default title of a note is stored in the language active when it was created.
- Interruptions, Bluetooth and route changes have not been verified here on a physical iPhone, and
  the performance figures still come from the simulator (see [PERFORMANCE.md](PERFORMANCE.md)).
- Nothing has been entered in App Store Connect: privacy labels, age rating and EU trader status are
  still to be completed.

## 0.1.0 — First complete build

The first version with the whole MVP in place: record, see the signal, keep the note, play it back.
It is a source release: you build it with Xcode and run it on a simulator or your own device. It is
**not** on TestFlight or the App Store.

### What you can do

- **Record** a voice note with one tap. Pause, resume, stop, or discard it. The first run asks for
  microphone access and explains what happens if you decline.
- **See what is being captured.** A live waveform scrolls while you record, at 20 samples a second.
- **Keep your notes.** Every recording is saved on the device with its date, duration and waveform
  and listed newest first. Nothing leaves the device.
- **Play them back.** Play, pause and seek, with a progress bar and the full waveform of the note.
- **Delete** a note and its audio file together, after a confirmation.
- **Survive real life.** Phone calls, another app taking the audio, headphones being unplugged, the
  app going to the background or the permission being withdrawn in Settings never lose what was
  already captured.

### Under the hood

- AVAudioEngine capture to AAC `.m4a`, with metering and downsampling done off the main thread.
- SwiftData for metadata and plain files for audio, reconciled at every launch after a crash.
- `@Observable` view models behind protocols; no third-party dependencies; Swift 6 strict concurrency.
- An interface drawn from the app icon: violet gradient, white rounded bars, coral accent, with a
  checked contrast ratio for every pairing and a dark mode.
- 157 tests in 25 suites, including long sessions and simulated interruptions.
- Measured on the simulator (see [PERFORMANCE.md](PERFORMANCE.md)): about 46 µs of work per 23 ms
  audio buffer, one hour of samples processed in about 0.7 s with 0.12 MB of growth, and a frame
  render of about 0.1 ms against a 16.7 ms budget.

### Fixed along the way

- **The live waveform froze after its first bar.** The canvas closure captured the same object on
  every update, so SwiftUI saw nothing to redraw. It now captures the change counter. Found while
  recording the demo; the unit tests cannot see rendering.

### Developer additions

- A Debug-only [demo mode](DEMO.md) with a seeded library and a synthetic recorder, plus a script
  to retake the screenshots.
- Documentation: [PRODUCT](PRODUCT.md), [ARCHITECTURE](ARCHITECTURE.md), [PERSISTENCE](PERSISTENCE.md),
  [AUDIO](AUDIO.md), [PERFORMANCE](PERFORMANCE.md) and [DEMO](DEMO.md).

### Known limits

- iPhone only, iOS 17 or later. Portrait is the designed layout.
- Interruption, route-change and permission handling is tested with fakes. It has **not** been
  checked on a physical device with a real call or real headphones.
- The performance figures come from the simulator on a Mac, not from an iPhone.
- No rename, search, share, export, folders, sync, accounts or transcription. These are out of scope
  by design.
- No Release-signed build, TestFlight build or App Store listing exists yet.
