# MURMUR — Audio Design and Trade-offs

How audio gets from the microphone to a saved file and back out, what happens when the system gets
in the way, and what each choice cost. This page is the map; the details live in the documents it
links to.

| Topic | Where |
| --- | --- |
| Layers, state ownership, concurrency | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Files, metadata, save/delete order, reconciliation | [PERSISTENCE.md](PERSISTENCE.md) |
| Test coverage and measured cost | [PERFORMANCE.md](PERFORMANCE.md) |
| Product scope and non-goals | [PRODUCT.md](PRODUCT.md) |

## Capture pipeline

```text
microphone → AVAudioSession → AVAudioEngine input tap (1,024 frames)
                                   │  audio thread, behind one lock
                                   ├─► AVAudioFile.write      AAC .m4a in tmp/Recording/
                                   ├─► vDSP RMS → peak over 50 ms → RecorderSample (~20 Hz)
                                   └─► WaveformDownsampler    ≤ 2 × 100 + 1 bars, saved with the file
                                        │
        AsyncThrowingStream, bufferingNewest(32)
                                        ▼
        RecorderViewModel (main actor) → LiveWaveform (120 bars) → Canvas
                                        └► stop(): RecordingRepository.save → Application Support/Recordings/
```

- `AudioRecorder` owns the engine and the file; `RecordingTapProcessor` is the only code that runs
  on the audio thread. It is a `final class` behind an `OSAllocatedUnfairLock` rather than an actor,
  because a real-time callback cannot await.
- The recording is written to a **temporary** file and only moved into the library by the
  repository on `stop()`. Discarding, or a crash, can therefore never leave a half-recording in the
  library; the launch-time reconciler removes orphans.
- Duration is `frames written / sample rate`, not the clock, so pauses and interruptions do not
  distort it.
- Playback uses `AVAudioPlayer` through the `AudioPlaying` protocol; a 20 Hz task polls its position
  for the slider and the playhead bar.

## One owner for the audio session

`AudioSessionManager` is the only place that touches `AVAudioSession` or the microphone permission.

| Activation | Category | Options |
| --- | --- | --- |
| Recording | `.playAndRecord` | `.defaultToSpeaker` |
| Playback | `.playback` | none |

- Recording activation is refused unless the permission is `.granted`: starting the engine without
  access does not fail, it records silence.
- The session is **deactivated with `.notifyOthersOnDeactivation`** as soon as nothing is capturing
  or playing, so music from other apps resumes.
- Bluetooth HFP microphones are left out on purpose (see trade-offs).

## Lifecycle and interruptions

`AudioSessionEvents` turns three `AVAudioSession` notifications into four events and fans them out
to every subscriber (the recorder and the player each get their own stream).

| Event | Recorder | Player |
| --- | --- | --- |
| `interruptionBegan` (call, Siri, alarm) | Pauses if recording and shows a notice. The recording stays open. | Pauses if playing and remembers it was playing. |
| `interruptionEnded(shouldResume:)` | Nothing. The user taps resume; `reactivate()` re-enables the session first. | Resumes only if it was playing **and** the system says `shouldResume`. |
| `routeLost` (headphones unplugged) | Nothing here; a lost input arrives as an engine configuration change (below). | Pauses, so audio does not jump to the speaker. |
| `mediaServicesReset` | Stops and **keeps what was captured**. | Unloads and asks to open the recording again. |

Other lifecycle rules:

- **Engine configuration change** (input device or sample rate changed under the engine): the file
  format no longer matches the hardware, so the recorder ends its sample stream with
  `configurationChanged` and the view model saves what was written.
- **Permission withdrawn in Settings**: `RootView` re-reads the permission whenever the scene
  becomes `.active`; if a capture is open and access is gone, the recording is saved and stopped.
- **Write failure** (disk full): the tap records the first error, stops writing and finishes the
  stream with it. Same outcome: keep what exists.
- **Launch after a crash**: `RecordingReconciler.run()` brings files and metadata back in line
  ([PERSISTENCE.md](PERSISTENCE.md)).

The common rule is **keep whatever was written**. A long recording is worth more than a clean
failure, so every recoverable error ends in a saved recording plus a message, never in a discarded
one. The only way to lose audio is to press discard.

These paths are tested with fakes (`FakeAudioSessionEvents`, `FakeAudioRecorder`,
`FakeAudioSession`); they have not been exercised against a real phone call on a physical device.

## Trade-offs

| Decision | Why | Cost |
| --- | --- | --- |
| `AVAudioEngine` tap instead of `AVAudioRecorder` | One code path gives raw buffers for the file and the meter, so levels and audio never drift apart. | More code: format handling, tap lifecycle and the configuration-change case are ours. |
| AAC `.m4a`, 64 kbit/s per channel, at the input's native rate | Small files (≈ 4.7 MB per 10 minutes mono) with good speech quality and no sample-rate conversion on the audio thread. | Lossy; not suited to music. The rate follows the hardware, so files from different devices differ. |
| Lock in the tap instead of an actor | A real-time thread cannot suspend. | `@unchecked Sendable`; correctness rests on the lock covering all mutable state. |
| Peak over a 50 ms window, not average | A short word still draws a visible bar. | Slightly exaggerates the loudness of clicks. |
| `bufferingNewest(32)` | A late main actor drops old meter samples instead of growing memory. | The live waveform can skip a bar under load; the audio itself is never dropped, because the file is written in the tap, not from the stream. |
| Fixed ring buffer (120 bars) for the live view | Memory does not depend on recording length. | Only the last 6 s are visible. |
| Progressive downsampling for the saved waveform | The summary is ≤ 201 bars whatever the duration. | Detail inside a bin is lost; the loudest moment is kept. |
| Interruption pauses instead of stopping | The user decides, and the recording stays one file. | The microphone is not retaken on its own, even when `shouldResume` is true. |
| Playback does resume after an interruption | Listening has no risk of recording something unwanted. | Asymmetric with the recorder; deliberate. |
| No Bluetooth HFP input | HFP is voice-call quality (8–16 kHz) and the option changed names across OS versions. | Headset microphones are not selectable; the built-in one is used. |
| Temporary file, then move | An aborted recording never appears in the library. | Needs the reconciler for crashes between steps. |
| `Canvas` for both waveforms | One draw pass instead of one view per bar. | The waveforms are hidden from VoiceOver; the library row (duration, date) and the player's position slider carry that information instead. |

## Measured optimizations

Summary of [PERFORMANCE.md](PERFORMANCE.md), simulator on a Mac (not iPhone figures):

| Concern | Result |
| --- | --- |
| Tap cost for a buffer | ≈ 46 µs against a 23,220 µs buffer: ≈ 0.2 % of the budget. |
| 10 minutes of audio through the capture path | 1.19 s; no memory growth observed. |
| 1 hour of 20 Hz samples through the recorder view model | 120 bars retained, ≈ 0.7 s, 0.12 MB steady-state growth. |
| Waveform rendering | ≈ 0.10 ms (live) and ≈ 0.13 ms (static) per frame, against 16.67 ms. |

What those numbers justified: nothing had to move off the audio thread, and the waveforms stay as
plain `Canvas` views. What they did not measure: energy, thermal behaviour and multi-hour recording
on a real device.

## Design tokens

The interface follows the app icon: a violet gradient, white rounded bars and one coral accent.
`Design/Brand.swift` holds the tokens (colors come from the asset catalog with light and dark
variants), `Design/BrandButtonStyles.swift` the round and pill buttons. `BrandContrastTests`
resolves the real catalog colors and checks WCAG contrast, so a palette change that hurts
legibility fails the suite.
