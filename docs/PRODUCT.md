# MURMUR — Product Definition

Phase 1 of the roadmap. This document fixes the problem, the MVP scope, the screens and the user
flows so that the audio architecture and persistence work can start without product ambiguity.

> **Positioning for launch** (niche, one-line proposal and differentiation) is at the
> [end of this document](#positioning-for-launch). The scope tables below describe the MVP as it was
> defined; transcription, search, renaming, tags and sharing were built afterwards (see
> [RELEASE_NOTES.md](RELEASE_NOTES.md)).

## Problem

Capturing a thought by voice should take one tap and no setup. Existing recorders either bury the
record button, hide what the microphone is actually hearing, or push accounts and sync on the user.

MURMUR is a small, local-only voice-notes app that:

- starts recording immediately and **shows the signal being captured** (live waveform), so the user
  knows the microphone is working before the thought is gone;
- keeps every note on the device with its metadata;
- lets the user find, replay and delete notes quickly.

It is also a deliberately technical project (see [PROJECT.md](PROJECT.md)): the product is intentionally small so
the engineering effort goes into audio capture, real-time rendering and lifecycle correctness.

## Target user

A single person on a single iPhone who wants quick personal voice notes. No sharing, no
collaboration, no account.

## MVP scope

| Area | In the MVP |
| --- | --- |
| Permissions | Request microphone access, explain denial, deep-link to Settings |
| Recording | Start, stop (save), discard, elapsed duration, live level + waveform |
| Library | Persisted list with title, duration and creation date; survives restarts |
| Playback | Play, pause, seek, progress, end-of-playback state |
| Management | Delete a recording (metadata and audio file together) |
| Reliability | Calls/interruptions, headphone/route changes, backgrounding, failures |

Pausing *during recording* is a reliability mechanism (interruptions) and is exposed in the UI, but
it is not a separate product feature.

### Explicitly out of scope

Accounts, backend, cloud sync, social features, AI transcription, advanced audio editing,
collaborative recordings and folder systems. Renaming, search, sharing/export and widgets are
**post-MVP** and must not shape the MVP architecture.

## Product decisions

These decisions unblock the architecture (#2) and persistence (#3) work.

| Decision | Choice | Reason |
| --- | --- | --- |
| Platform | iPhone, iOS 17+ | `@Observable`, SwiftData and `AVAudioApplication` permission API |
| Storage | Local only (app container) | No backend in scope |
| Audio format | AAC in `.m4a`, mono/stereo as the input provides | Small files, native playback, no conversion step |
| Default title | `Recording <date and time>` | Zero friction at capture time; renaming is post-MVP |
| Background | Recording and playback continue when the app is backgrounded | Matches user expectation for voice memos |
| Interruption | A call pauses the recording; it resumes automatically only if the system asks to | Never silently lose or extend a note |
| Failure | Whatever was captured is kept when a recoverable failure ends a recording | Notes are more valuable than perfect state |

## Screens

### 1. Library (home)

- Large navigation title **MURMUR**.
- List of recordings, newest first. Each row: title, duration, creation date.
- Primary **Record** button always reachable (bottom of the screen).
- Swipe to delete. Tap a row to open the player.
- Empty state explaining how to record the first note.

### 2. Recorder (modal)

- Elapsed time, large, updating while recording.
- Live waveform showing the most recent audio.
- Controls: **Stop** (save), **Pause/Resume**, **Discard**.
- Permission states: *not determined* (request on first use), *denied* (explanation + button to
  open Settings, recording never starts).
- Error banner for failures (input unavailable, disk full, route lost).

### 3. Player

- Title, creation date, total duration.
- Static waveform of the saved recording with a progress indicator.
- Play/Pause, scrubber (seek), elapsed / remaining time.
- Returns to a stopped state at the end of playback; Play restarts from the beginning.

## User flows

### Record and save

1. User taps **Record** in the Library.
2. If permission is undetermined, the system prompt is shown. On **denied** → *Permission denied*
   flow; recording does not start.
3. Recorder opens and starts capturing; timer and waveform update live.
4. User taps **Stop**. The audio file is finalized, metadata is persisted, the recorder closes and
   the new note appears at the top of the Library.

### Discard

1. While recording (or paused), user taps **Discard** and confirms.
2. Capture stops, the temporary file is deleted, nothing is persisted. Library is unchanged.

### Permission denied

1. Recorder shows why the microphone is needed and a button that opens the app's Settings page.
2. When the user returns to the app, the permission is re-read; if now granted, recording can start.

### Interruption (call, Siri, other app takes the session)

1. Recording pauses and the UI shows it as paused.
2. If the system says the recording may resume, it resumes. Otherwise it stays paused and the user
   chooses **Resume**, **Stop** (save what exists) or **Discard**.

### Route change (headphones/Bluetooth)

- Recording continues across a route change when the capture format is unchanged. If the input
  format changes mid-recording, the note captured so far is saved and the user is told why.
- Playback pauses when the output device disappears (e.g. headphones unplugged).

### List and play

1. Library lists persisted recordings after every launch.
2. Tapping a row opens the Player; Play starts playback, Pause holds position, dragging the scrubber
   seeks, end of audio returns to the stopped state.

### Delete

1. User swipes a row and confirms **Delete**.
2. Metadata and audio file are both removed. If one step fails, the app stays consistent and the
   next launch reconciles any leftover data (see persistence design).

## Definition of done for the MVP

- All flows above work on a device, including the interruption and route-change cases.
- The waveform stays smooth and memory stays bounded during long recordings.
- State owned by the recorder, player, persistence and SwiftUI is separated (see the architecture
  document).
- Unit tests cover state transitions, waveform buffer bounds and deletion consistency.
- Architecture, audio pipeline and trade-offs are documented.

## Positioning for launch

Decision for issue #31, taken on October 14, 2026. The *niche* is a choice; the claims about users and
about Voice Memos below are **hypotheses to test**, not findings. See [Validation](#validation).

### Niche

- **Primary: spoken journals.** People who talk through their day or their thoughts and want to keep it
  private. Privacy is the argument that matters most to them, and they search their own past often.
- **Secondary: students and journalists.** Lectures, interviews and reporting notes that must be found
  again by what was said. Here the open question is how well on-device transcription holds up on long,
  noisy audio (not measured yet).
- **Not now:** music ideas (transcription adds nothing) and hands-free car notes (needs quick capture,
  issue #36, which does not exist yet).

### Proposition, in one sentence

> MURMUR is the voice notebook that turns what you say into searchable text without your audio ever
> leaving your iPhone.

### The three features that carry it

| Feature | State | What the user gets |
| --- | --- | --- |
| **Private transcription** | Built (#33) | Text from every note, on the device, with on-device recognition required. No account, no server. |
| **Search** | Built (#34) | Find a note by title, tag or anything said in it, and jump to the moment. |
| **Quick capture** | Not built (#36) | Start recording from the lock screen or a button, before the thought is gone. |

Everything else (export as `.txt`/`.md`, editing the transcript, six interface languages) supports these
three and does not need its own message. Priorities for the open issues follow from this table: #36 comes
next because it is the only pillar missing; #37 (AI summaries) and #38 (iCloud/iPad) come after the niche
is validated, and #37 must not break the "nothing leaves your device" promise.

### Against Voice Memos

Voice Memos is free, preinstalled and also transcribes, so "it transcribes" is not a differentiator. What
MURMUR bets on (to verify by hand in the same iOS version before using any of it in public copy):

- **Tags plus search across titles and transcripts**, landing on the exact moment in the audio.
- **Export of audio and text** as plain files (`.m4a`, `.txt`, `.md`) for notes apps and editors.
- **A stated privacy promise**: recognition is forced on-device and there is no fallback to a server;
  if a language is not available offline, the app says so.
- **Six interface languages** (en, es, fr, de, it, pt).

What MURMUR does not try to beat: sync across devices, a Mac app, or being preinstalled.

### Validation

Nothing here is validated until people outside the project say so.

1. Talk to 5 to 10 people in each niche. Use [INTERVIEW_GUIDE.md](INTERVIEW_GUIDE.md).
2. Publish the [landing page](index.html) (GitHub Pages from `/docs`) and measure interest. The
   indicative target is 100 visits and 10 sign-ups; it is a hypothesis, not a promise.
3. After the interviews, change this section: keep the niche that shows real pull, drop the other.
