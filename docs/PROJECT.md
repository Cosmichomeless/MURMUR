# MURMUR — Project brief and roadmap

The original goals, stack, engineering challenges and roadmap of the project. They used to be the
README; the README is now the cover page. Product scope is in [PRODUCT.md](PRODUCT.md) and the
current design in [ARCHITECTURE.md](ARCHITECTURE.md).

MURMUR is a native iOS voice-notes app built to explore audio recording and real-time audio
visualization with Apple's own frameworks. The goal is not another voice recorder: it is to
understand how audio capture, audio sessions, buffers, real-time rendering, local persistence and
the iOS application lifecycle work together.

## Goals

What the project is meant to exercise:

- Swift, SwiftUI and Swift Concurrency
- AVFoundation: `AVAudioSession`, `AVAudioEngine`, audio buffers and metering
- Real-time waveform rendering
- SwiftData
- The iOS application lifecycle, audio interruptions and route changes
- Native iOS architecture and testing

## Tech stack

| Area | Choice |
| --- | --- |
| Language | Swift 6 |
| UI | SwiftUI |
| Audio | AVFoundation (`AVAudioEngine`, `AVAudioSession`, `AVAudioPlayer`) |
| Signal processing | Accelerate (`vDSP`) |
| Persistence | SwiftData for metadata, plain files for audio |
| Concurrency | Swift Concurrency (`async/await`, `AsyncThrowingStream`) |
| Tests | Swift Testing |
| Dependencies | None. Native frameworks only, unless a library gives a clear technical benefit |

## Key engineering challenges

- **Real-time waveform.** Update smoothly from a bounded rolling buffer, without redrawing the
  whole view hierarchy, without growing memory in long recordings. See
  [AUDIO.md](AUDIO.md) and [PERFORMANCE.md](PERFORMANCE.md).
- **Audio session management.** Incoming calls, interruptions, headphones connecting and
  disconnecting, route changes, backgrounding, permission changes and recording failures. See
  [AUDIO.md](AUDIO.md).
- **Persistence.** Audio files and metadata stay in sync: deleting a recording removes both. See
  [PERSISTENCE.md](PERSISTENCE.md).

## Original data model sketch

The first sketch, before the persistence phase. The real model differs (it stores `fileName`, not an
absolute URL, and `waveformData` as bytes): see [PERSISTENCE.md](PERSISTENCE.md).

```text
Recording
├── id
├── title
├── fileURL
├── duration
├── createdAt
└── waveformData
```

## Roadmap

All twelve phases are done as of `0.1.0`.

| Phase | Scope | Where it ended up |
| --- | --- | --- |
| 1. Product definition | Problem, scope, MVP, screens, flows | [PRODUCT.md](PRODUCT.md) |
| 2. Architecture | Layers, audio architecture, state ownership | [ARCHITECTURE.md](ARCHITECTURE.md) |
| 3. Persistence | Recording model, SwiftData, file management | [PERSISTENCE.md](PERSISTENCE.md) |
| 4. Recording engine | Permissions, `AVAudioSession`, start/stop lifecycle | `MURMUR/Audio/` |
| 5. Live waveform | Metering, buffer processing, amplitude sampling, rendering | `MURMUR/Features/Waveform/` |
| 6. Recording library | Persistence, list, metadata, deletion | `MURMUR/Features/Library/` |
| 7. Audio player | Playback, pause, seek, progress | `MURMUR/Features/Player/` |
| 8. Reliability | Interruptions, route changes, background, permission changes | [AUDIO.md](AUDIO.md) |
| 9. Testing | Unit, audio logic and persistence tests | `MURMURTests/`, [PERFORMANCE.md](PERFORMANCE.md) |
| 10. Optimization | CPU, memory, rendering, long sessions | [PERFORMANCE.md](PERFORMANCE.md) |
| 11. Documentation | Architecture, audio pipeline, decisions, trade-offs | [ARCHITECTURE.md](ARCHITECTURE.md), [AUDIO.md](AUDIO.md) |
| 12. Release | Screenshots, demo, release notes, final documentation | [DEMO.md](DEMO.md), [RELEASE_NOTES.md](RELEASE_NOTES.md) |

Beyond the roadmap, the interface was redrawn from the app icon's visual style, and the README was
rewritten as a cover page.

## Out of scope

No accounts, backend, cloud sync, social features, AI transcription, advanced audio editing,
collaborative recordings or folder systems. The project prioritizes technical depth over feature
count: the objective is not "build a voice recorder" but "build a native iOS audio application with
real-time processing, efficient rendering, reliable lifecycle management and clean architecture".
