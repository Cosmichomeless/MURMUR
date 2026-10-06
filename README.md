# MURMUR

## Project Overview

MURMUR is a mobile voice-notes application focused on real-time audio recording and visualization.

The main objective of the project is not simply to build another voice recorder, but to explore audio processing, real-time UI rendering, local storage and mobile application lifecycle management.

The application should allow the user to record a voice note while seeing the waveform being drawn in real time.

The project is intended to be a technically focused mobile application suitable for a software engineering portfolio.

---

## Main Goal

Build a polished mobile voice recorder capable of:

- Recording audio.
- Displaying a live waveform while recording.
- Showing recording duration.
- Showing basic audio metering.
- Saving recordings locally.
- Listing previous recordings.
- Playing recordings.
- Deleting recordings.
- Handling microphone permissions correctly.
- Recovering gracefully from interruptions.

The application should remain relatively small in functionality but technically deep.

---

# Core Concept

The main screen should behave similarly to a professional field recorder.

During recording, the user should see:

- Live waveform.
- Recording timer.
- Audio level / peak information.
- Record / stop control.
- Optional marker button.
- Recording state.

Example:

REC ●

02:47

████████████████
live waveform

Peak: -4.2 dB

[Discard] [Stop] [Marker]

Below the recorder, recent recordings should be displayed.

---

# Technical Objectives

This project should teach and demonstrate:

- Mobile microphone permissions.
- Audio recording.
- Audio session management.
- Real-time audio metering.
- Real-time graphical rendering.
- React Native performance.
- File management.
- Application lifecycle management.
- Local persistence.
- State management.
- Audio playback.
- Handling interruptions such as:
  - phone calls
  - app going into background
  - audio route changes
  - permission changes

---

# Technology Stack

## Mobile

- React Native
- Expo
- TypeScript

## Audio

- expo-audio

## Graphics

- React Native Skia

The waveform should be rendered using Skia rather than building hundreds of React components.

## State Management

- Zustand

## Local Persistence

Possible options:

- MMKV
- SQLite

The final choice should be made during the architecture phase.

## Styling

- NativeWind

---

# Functional Requirements

## Recording

The user must be able to:

- Start a recording.
- Pause a recording if supported by the chosen architecture.
- Stop a recording.
- Cancel/discard a recording.
- See recording duration.
- See live audio levels.

---

## Live Waveform

While recording:

- Audio amplitude should be sampled periodically.
- Samples should be stored in a small rolling buffer.
- The waveform should update smoothly.
- Rendering should avoid unnecessary React re-renders.
- The UI should remain responsive.

Target:

60 FPS whenever possible.

---

## Recording Library

Saved recordings should contain:

- ID.
- Filename.
- Creation date.
- Duration.
- File path.
- Optional title.
- Optional waveform preview.
- Optional markers.

Example:

VoiceNote {
    id
    title
    fileUri
    duration
    createdAt
    waveformData
}

---

## Playback

The user should be able to:

- Play a recording.
- Pause playback.
- Seek through the recording.
- See playback progress.
- Delete the recording.

---

# Optional Feature: Markers

During recording, the user may press a marker button.

Example:

00:32 — Marker
01:14 — Marker
02:05 — Marker

Markers should allow the user to quickly return to important moments.

This feature should only be implemented after the core recording functionality is stable.

---

# Architecture

Suggested structure:

src/

components/
    Waveform/
    RecorderControls/
    RecordingCard/

features/
    recorder/
    recordings/
    player/

services/
    audio/
    storage/

store/
    recorderStore.ts
    recordingsStore.ts

hooks/
    useRecorder.ts
    useAudioMeter.ts

types/

utils/

---

# Important Technical Challenge

The main technical challenge is:

REAL-TIME AUDIO → UI

Possible flow:

Microphone
    ↓
Audio Metering
    ↓
Amplitude Samples
    ↓
Rolling Buffer
    ↓
Skia Canvas
    ↓
Live Waveform

The implementation should avoid updating the entire React tree for every audio sample.

---

# MVP

The first production-ready version should include only:

- Microphone permission.
- Start recording.
- Stop recording.
- Live waveform.
- Recording duration.
- Save recording locally.
- Recording list.
- Playback.
- Delete recording.

Everything else is secondary.

---

# Features Outside the Initial MVP

Do NOT implement initially:

- User accounts.
- Cloud synchronization.
- Social features.
- AI transcription.
- Sharing system.
- Collaborative recordings.
- Backend.
- Complex folders.
- Advanced audio editing.

These features may be considered only after the core application is complete.

---

# Development Philosophy

The project should prioritize:

1. Correct audio handling.
2. Smooth waveform rendering.
3. Clean architecture.
4. Mobile performance.
5. Good UX.
6. Testing.
7. Documentation.

Avoid unnecessary features.

The objective is technical depth, not feature count.

---

# Development Phases

## Phase 1 — Product Definition

Define:

- User problem.
- User flow.
- MVP.
- Screens.
- UX.

## Phase 2 — Architecture

Define:

- Audio architecture.
- State management.
- Local persistence.
- File structure.

## Phase 3 — Recording Engine

Implement:

- Permissions.
- Recording.
- Stop.
- Save.

## Phase 4 — Live Waveform

Implement:

- Audio metering.
- Sampling.
- Waveform buffer.
- Skia rendering.

## Phase 5 — Recording Library

Implement:

- Persistence.
- Recording list.
- Metadata.

## Phase 6 — Playback

Implement:

- Player.
- Seek.
- Progress.

## Phase 7 — Reliability

Handle:

- Background state.
- Audio interruptions.
- App crashes.
- Permission errors.

## Phase 8 — Testing and Documentation

Add:

- Tests.
- Architecture documentation.
- README.
- Demo video.
- Screenshots.

---

# Portfolio Value

This project should demonstrate knowledge of:

- React Native.
- Mobile APIs.
- Audio processing.
- Real-time rendering.
- Performance optimization.
- Local persistence.
- State management.
- Mobile lifecycle management.

The project should be presented as an audio engineering / mobile systems project rather than simply a voice recorder.
