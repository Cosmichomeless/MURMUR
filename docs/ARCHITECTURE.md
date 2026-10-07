# MURMUR — Architecture

Phase 2 of the roadmap: the audio pipeline, the state ownership and the dependency boundaries.
Product scope lives in [PRODUCT.md](PRODUCT.md).

## Principles

1. **One owner per piece of state.** Recorder, player, persistence and SwiftUI each own their own
   state; they communicate through small value types and protocols, never by sharing objects.
2. **The audio thread never touches UI or persistence.** Real-time callbacks only compute and hand
   off plain values.
3. **Native frameworks only.** AVFoundation, Accelerate, SwiftData, SwiftUI, Swift Concurrency.
4. **Views are dumb.** Views render state and send intents; view models translate between them.

## Layers and dependency rules

```text
┌──────────────────────────── SwiftUI Views ────────────────────────────┐
│  Features/Recorder      Features/Recordings      Features/Player       │
└───────────────▲──────────────────▲──────────────────────▲─────────────┘
                │ observes         │ observes             │ observes
┌───────────────┴──────────────────┴──────────────────────┴─────────────┐
│                  View models  (@Observable, @MainActor)               │
└───────▲───────────────────▲───────────────────▲───────────────▲───────┘
        │ protocol          │ protocol          │ protocol      │
┌───────┴────────┐ ┌────────┴────────┐ ┌────────┴───────┐ ┌─────┴───────────┐
│ AudioRecording │ │  AudioPlaying   │ │ AudioSession-  │ │ Recording       │
│ (AVAudioEngine)│ │ (AVAudioPlayer) │ │ Controlling    │ │ Repository      │
└────────────────┘ └─────────────────┘ │ (AVAudioSession)│ │ (SwiftData+files)│
                                       └────────────────┘ └─────────────────┘
```

Rules:

- Views depend on view models only. They never import AVFoundation or SwiftData queries beyond the
  `@Query` used by the Library list.
- View models depend on **protocols** (`AudioRecording`, `AudioPlaying`, `AudioSessionControlling`,
  repository) injected at creation, so they are testable without a microphone.
- `Audio/` does not import SwiftData or SwiftUI. `Persistence/` does not import AVFoundation
  (durations and waveforms arrive as values).
- `AVAudioSession` is configured in exactly one place (`AudioSessionControlling`).
- Cross-layer data are value types: `RecorderSample`, `RecordedAudio`, `PlayerState`,
  `MicrophonePermission`.

## Folder layout

```text
MURMUR/
├── App/              app entry point, dependency container, root navigation
├── Audio/            session, recorder, player, waveform math (no UI, no SwiftData)
├── Persistence/      SwiftData model, file store, repository
├── Features/
│   ├── Recorder/     recorder screen + view model
│   ├── Recordings/   library screen + view model
│   └── Player/       player screen + view model
├── Components/       reusable views (waveform, buttons)
└── Utilities/        small shared helpers
MURMURTests/          Swift Testing unit tests
docs/                 product, architecture and release documents
```

The Xcode project uses synchronized folders: a file added under `MURMUR/` or `MURMURTests/` joins
its target automatically.

## Audio pipeline

```text
Microphone
   │
   ▼
AVAudioSession          category .playAndRecord, activated by AudioSessionControlling
   │
   ▼
AVAudioEngine.inputNode installTap(bufferSize: 1024)
   │   audio thread ─────────────────────────────────────────────┐
   ▼                                                              │
AVAudioPCMBuffer ──► AVAudioFile.write (AAC .m4a, tmp/)           │ never leaves this thread:
   │                                                              │ no UI, no SwiftData, no allocations
   ▼                                                              │ beyond the AsyncStream element
vDSP RMS per buffer → peak over a ~50 ms window (20 Hz)  ◄────────┘
   │
   ▼  AsyncThrowingStream<RecorderSample>   (bufferingNewest, bounded)
   │
   ▼  @MainActor consumer (RecorderViewModel)
   ├──► LiveWaveform  rolling buffer (fixed capacity)  ──► SwiftUI Canvas
   └──► WaveformDownsampler (bounded) ──► RecordedAudio.waveform ──► Recording.waveformData
```

Key decisions:

- **Engine tap, not `AVAudioRecorder`.** The tap gives raw buffers for exact level computation and a
  single code path for file writing and metering.
- **Level computation on the audio thread, rendering on the main actor.** Only a pair of `Float`/
  `Double` values crosses the thread boundary through an `AsyncStream`.
- **Bounded everywhere.** The stream drops old samples under pressure; the live waveform is a ring
  buffer; the saved waveform is downsampled progressively so memory does not grow with duration.
- **Duration is frames written / sample rate**, not wall-clock time, so pauses and interruptions do
  not distort it.

## State ownership

| State | Owner | Type | Observed by |
| --- | --- | --- | --- |
| Microphone permission, session activation | `AudioSessionControlling` implementation | `MicrophonePermission` | Recorder view model |
| Recorder lifecycle (idle / recording / paused / failed) | `RecorderViewModel` (state machine) | `RecorderState` | Recorder view |
| Elapsed duration, current level | `RecorderViewModel` | `TimeInterval`, `Float` | Recorder view |
| Live waveform window | `LiveWaveform` (own `@Observable`) | ring buffer | Waveform view only |
| In-flight capture (engine, file) | `AudioRecording` implementation | private | — |
| Playback position and state | `PlayerViewModel` over `AudioPlaying` | `PlayerState`, `TimeInterval` | Player view |
| Saved recordings | SwiftData `ModelContext` through the repository | `Recording` | Library (`@Query`) |
| Audio files | `RecordingFileStore` | files on disk | Repository only |

Why the live waveform is a separate observable: if elapsed time, buttons and the waveform lived in
one observable object, every 50 ms sample would invalidate the whole recorder view. Keeping the
waveform window in its own object means only the `Canvas` re-renders at 20 Hz; the timer text and
controls update on their own cadence.

## Concurrency model

- View models, session controller, recorder and player facades are `@MainActor`.
- The audio tap runs on the engine's audio thread. Everything it captures is `Sendable` or is a
  lock-protected reference (`RecordingTapProcessor`) so Swift 6 strict concurrency holds.
- Samples travel through `AsyncThrowingStream` with `bufferingNewest`; the consumer is a single
  `Task` owned by the recorder view model and cancelled on stop/discard.
- No `DispatchQueue` for app logic; no unstructured `Task {}` without an owner.

## Persistence boundary

SwiftData stores metadata; the audio file lives in the file system. They are kept consistent by the
repository using a defined order of operations and a launch-time reconciliation. Details and the
file locations are in the persistence design (issue #3, `docs/PERSISTENCE.md` once added).

## Error handling

- Recoverable audio failures (input lost, route format change, disk full) end the capture, **keep
  whatever was written** and surface a user-facing message.
- Programmer errors are not silenced: `AudioRecording`/`AudioPlaying` throw typed errors;
  view models map them to messages.
- Permission is re-read whenever the app becomes active.

## Testing strategy

| Concern | How |
| --- | --- |
| Recorder state machine | Pure value-type transitions, no audio hardware |
| Level math, waveform ring buffer, downsampler | Pure functions over `[Float]` |
| Tap processing and file writing | Synthetic `AVAudioPCMBuffer` fed to the processor |
| Persistence and deletion consistency | In-memory `ModelContainer` + temp directory |
| View models | Fakes of the audio and repository protocols |

## Non-goals

No dependency injection framework, no Combine, no Redux-style store, no third-party packages.
