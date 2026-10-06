# MURMUR

> Native iOS voice notes application focused on real-time audio recording, waveform visualization, and audio lifecycle management.

## Overview

MURMUR is a native iOS voice-notes application built to explore audio recording and real-time audio visualization using Apple's native frameworks.

The goal of the project is not simply to build another voice recorder. MURMUR is designed as a technically focused project to understand how audio capture, audio sessions, buffers, real-time rendering, local persistence, and the iOS application lifecycle work together.

The application will allow users to record voice notes while seeing a waveform generated in real time, save recordings locally, and play them back later.

## Goals

The project is designed to explore and demonstrate knowledge of:

- Swift
- SwiftUI
- AVFoundation
- AVAudioSession
- AVAudioEngine
- Audio buffers
- Audio metering
- Real-time waveform rendering
- Swift Concurrency
- SwiftData
- iOS application lifecycle
- Audio interruptions and route changes
- Native iOS architecture
- Testing

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Audio:** AVFoundation
- **Audio Processing:** Accelerate where appropriate
- **Persistence:** SwiftData
- **Concurrency:** Swift Concurrency
- **Testing:** Swift Testing / XCTest
- **Dependency Management:** Swift Package Manager

The project prioritizes native Apple frameworks and avoids third-party dependencies unless they provide a clear technical benefit.

## Core Architecture

The main audio pipeline will follow a structure similar to:

```text
Microphone
    ↓
AVAudioSession
    ↓
AVAudioEngine
    ↓
Audio Buffers
    ↓
Amplitude Samples
    ↓
Rolling Waveform Buffer
    ↓
SwiftUI
```

One of the main engineering challenges is updating the waveform smoothly without causing unnecessary updates across the entire SwiftUI view hierarchy.

## MVP

The first production-ready version should support:

- Microphone permissions
- Start recording
- Stop recording
- Discard recording
- Recording duration
- Real-time audio level
- Live waveform visualization
- Local audio file storage
- Recording metadata persistence
- Recording library
- Audio playback
- Pause playback
- Seek
- Delete recording

## Data Model

Initial recording model:

```text
Recording
├── id
├── title
├── fileURL
├── duration
├── createdAt
└── waveformData
```

The final model may evolve during the architecture and persistence phases.

## Key Engineering Challenges

### Real-Time Waveform

Audio amplitude samples must be collected and transformed into data suitable for rendering.

The waveform should:

- Update smoothly
- Use a bounded rolling buffer
- Avoid excessive SwiftUI updates
- Remain responsive during long recordings
- Avoid unnecessary memory allocation

### Audio Session Management

The application should correctly handle:

- Incoming calls
- Audio interruptions
- Headphone connection/disconnection
- Audio route changes
- App backgrounding
- Permission changes
- Recording failures

### Persistence

Audio files and recording metadata must remain synchronized.

Deleting a recording should correctly remove both its metadata and associated audio file.

## Project Structure

The exact structure will be defined during the architecture phase, but the project should separate concerns such as:

```text
MURMUR/
├── App/
├── Features/
│   ├── Recorder/
│   ├── Recordings/
│   └── Player/
├── Audio/
├── Persistence/
├── Models/
├── Components/
├── Utilities/
└── Tests/
```

## Development Roadmap

### Phase 1 — Product Definition

Define:

- User problem
- Product scope
- MVP
- Main screens
- User flows

### Phase 2 — Architecture

Define:

- Application architecture
- Audio architecture
- Dependency boundaries
- State ownership

### Phase 3 — Persistence

Define:

- Recording model
- SwiftData model
- Audio file management strategy

### Phase 4 — Recording Engine

Implement:

- Permissions
- AVAudioSession
- Audio recording
- Start/stop lifecycle

### Phase 5 — Live Waveform

Implement:

- Audio metering
- Buffer processing
- Amplitude sampling
- Waveform rendering

### Phase 6 — Recording Library

Implement:

- Recording persistence
- Recording list
- Metadata management
- Deletion

### Phase 7 — Audio Player

Implement:

- Playback
- Pause
- Seek
- Progress tracking

### Phase 8 — Reliability

Handle:

- Interruptions
- Route changes
- Background state
- Permission changes
- Failure recovery

### Phase 9 — Testing

Add:

- Unit tests
- Audio logic tests
- Persistence tests

### Phase 10 — Optimization

Analyze:

- CPU usage
- Memory usage
- Rendering performance
- Long recording sessions

### Phase 11 — Documentation

Document:

- Architecture
- Audio pipeline
- Technical decisions
- Trade-offs

### Phase 12 — Release

Prepare:

- Screenshots
- Demo
- Release notes
- Final documentation

## Out of Scope

The initial version will not include:

- User accounts
- Backend
- Cloud synchronization
- Social features
- AI transcription
- Advanced audio editing
- Collaborative recordings
- Complex folder systems

The project prioritizes technical depth over feature count.

## Project Philosophy

MURMUR should remain relatively small in functionality while exploring audio engineering in depth.

The objective is not:

> Build a voice recorder.

The objective is:

> Build a native iOS audio application with real-time processing, efficient rendering, reliable lifecycle management, and clean architecture.

## Status

🚧 **In development**

Current stage:

**Phase 1 — Product Definition**
