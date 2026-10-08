# Demo mode

A reproducible run of the app for screenshots and walkthroughs. It needs no microphone, no
permission prompt and no data: the library is filled with five invented recordings and the recorder
produces a synthetic voice. Everything above that seam (view models, views, repository, player) is
the production code.

Demo mode exists only in **Debug** builds. The whole `MURMUR/App/Demo/` folder is wrapped in
`#if DEBUG`, so a Release build cannot be started in it.

## Run it

You need Xcode and an iOS 17+ simulator. These commands work from a clean clone.

```sh
# 1. Build the app for a simulator (pick any available device name)
xcodebuild build -project MURMUR.xcodeproj -scheme MURMUR \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO

# 2. Install it on the booted simulator and launch it in demo mode
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/MURMUR.app
xcrun simctl launch booted com.cosmichomeless.murmur -murmur-demo
```

If no simulator is booted, run `xcrun simctl boot "iPhone 17"` first, or open the project in Xcode
and add the launch arguments under *Product → Scheme → Edit Scheme → Run → Arguments*.

## Launch arguments

| Argument | Effect |
| --- | --- |
| `-murmur-demo` | Seeded library, synthetic recorder, in-memory metadata, throwaway files |
| `-murmur-demo-empty` | Same, but starts with no recordings (the first-run screen) |
| `-murmur-demo-screen recorder` | Opens the recorder and starts recording |
| `-murmur-demo-screen player` | Opens "Voice memo for Ana" at 35 % of its length, paused |

`-murmur-demo-screen` can be combined with `-murmur-demo`. It is read by `LibraryView` in Debug only.

What demo mode never touches: the real recordings folder (files live in a temporary
`MURMUR-Demo/` folder that is wiped at every launch), the real SwiftData store (it is held in
memory), the microphone and the microphone permission.

## Walkthrough: record → waveform → library → playback

1. **Launch** with `-murmur-demo`. The library shows five recordings, newest first.
2. **Record.** Tap the coral microphone button. The recorder opens, the clock starts and the
   waveform scrolls in from the right, 20 samples a second. Tap pause to freeze it, trash to discard.
3. **Stop.** Tap the white stop button. The capture is written to an `.m4a`, saved through the real
   `RecordingRepository` and the sheet closes. The new recording appears at the top of the library.
4. **Play.** Tap any recording. The player draws its waveform, and the progress bar and the
   waveform highlight move together. Drag the slider to seek.
5. **Delete.** Swipe a row left and confirm. The audio file is removed with its metadata.

The synthetic voice is deterministic: the same seed gives the same levels, so the waveform and the
sound are identical on every run. Because the recorder runs in real time, the clock in a recorder
screenshot depends on when it is taken (a fraction of a second either way).

## Retake the screenshots

```sh
docs/screenshots/capture.sh            # uses the booted simulator
docs/screenshots/capture.sh <udid>     # or a specific one
```

The script builds the Debug app, launches each screen, captures the simulator at its native
resolution with a fixed `9:41` status bar and shrinks every PNG with `docs/screenshots/optimize.py`
(Pillow is required) to stay under 400 KB. The result is written over the four files in
`docs/screenshots/`.

| File | Screen |
| --- | --- |
| `01-library.png` | Library with five recordings |
| `02-recorder.png` | Recorder with the live waveform |
| `03-player.png` | Player, paused at 35 % |
| `04-empty.png` | First-run empty library |

## Tests

`MURMURTests/App/DemoModeTests.swift` keeps the demo honest: the synthetic voice is deterministic
and in range, the audio it writes is a playable file of the right length, the seeded library goes
through the real repository (files, waveform bounds, unique titles), and the demo recorder drives the
real `RecorderViewModel` through start and stop and saves a recording.
