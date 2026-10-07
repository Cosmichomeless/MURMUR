# MURMUR — Quality and Performance

How the audio logic, persistence and long recordings are tested, and what a long session costs.
Architecture context: [ARCHITECTURE.md](ARCHITECTURE.md). Persistence design:
[PERSISTENCE.md](PERSISTENCE.md).

## What the tests cover

| Area | Test file | What it proves |
| --- | --- | --- |
| Recording state transitions | `RecorderStateMachineTests` | Every state × event pair (4 × 7) against an explicit table; a failure is only reachable through a `fail` event; 20,000 seeded random events never leave a valid state and `isCapturing` always matches the state. |
| Recorder view model | `RecorderViewModelTests` | Start/pause/resume/stop/discard, failures, interruptions, route loss, permission withdrawal: captured audio is never lost. |
| Waveform buffer bounds | `WaveformBoundsTests` | The ring buffer equals "the last N of a reference array" after every append for capacities 1, 2, 3, 7, 120, including after `removeAll` mid-wrap; the downsampler never exceeds `2 × bins + 1` values, keeps the loudest moment and does not grow between 10 thousand and 2 million samples. |
| Library ↔ files consistency | `LibraryConsistencyTests` | 200 seeded random saves/deletes keep the library and the recordings folder identical after every step and leave nothing for reconciliation to fix; a simulated crash between steps is repaired; recorder → library works end to end (stop, discard, interruption). |
| Long sessions | `LongSessionTests` | Cost and boundedness over an hour of meter samples, ten minutes of real audio through the capture path, and rendering (below). |

Randomized tests use `SeededGenerator` (SplitMix64), so a failure reproduces identically.

While writing the long-session test it found a flaw in a **test double**, not in the app: the fake
recorder's stream was unbounded, unlike the real recorder's `bufferingNewest(32)`, so the test was
measuring its own backlog (20 MB growth, consumer 10× behind). The fake now uses the same policy.

## How it was measured

`ResourceProbe` (in `MURMURTests/Support`) reads wall time, process CPU time (`getrusage`) and
resident memory (`mach_task_basic_info`). Each long-session test prints one `METRIC …` line and
asserts a deliberately generous bound: tight enough to catch accidental O(n) growth or a 10×
slowdown, loose enough not to flake. To reproduce:

```sh
xcodebuild test -project MURMUR.xcodeproj -scheme MURMUR \
  -destination 'platform=iOS Simulator,name=iPhone 16' | grep METRIC
```

**These are simulator-on-Mac numbers.** They show how cost *scales* and where the headroom is;
they are not iPhone figures. Resident-memory deltas are noisy because Swift Testing runs other
suites in the same process: a negative value means "no growth", not that memory was freed by the
code under test. The hour-long test therefore measures *steady state* (growth after a 10-minute
warm-up) rather than total growth, which includes one-off allocations and code paging. The structural bounds (bar count, bin count) are exact.

## Results

Measured on a Mac simulator, 2026-10-07.

### Capture path — 10 minutes of audio

`RecordingTapProcessor.process` fed 25,839 buffers of 1,024 frames at 44.1 kHz (a sine tone),
writing AAC to a real `.m4a`, as fast as the machine allows.

| Metric | Result |
| --- | --- |
| Wall time for 10 min of audio | 1.19 s (≈ 500× real time) |
| Cost per buffer | ≈ 46 µs, against a 23,220 µs buffer duration (0.2 % of the budget) |
| File size | 4,805 KB (AAC, 64 kbit/s mono) |
| Waveform summary | 188 bins, ≤ 201 by construction |
| Memory growth | none observed (≈ −1 MB, i.e. noise; no per-sample state by design) |

The tap holds a lock and does a file write, an RMS (`vDSP`) and one bin update per buffer. At
≈ 0.2 % of the buffer budget there is large headroom on the audio thread, even on a device
several times slower than the host.

### Meter stream — 1 hour at 20 Hz

72,000 samples through `RecorderViewModel` with the recorder's stream policy:

| Metric | Result |
| --- | --- |
| Live bars retained | 120 (the last 6 s), exactly the ring buffer capacity |
| Elapsed shown | equals the last sample, exact |
| Wall time to process one hour of samples | ≈ 0.7 s |
| Memory growth over the last 50 min (after a 10 min warm-up) | 0.12 MB |

The ring buffer has a fixed size, so a recording of any length uses the same memory for the live
waveform, and `bufferingNewest(32)` bounds the backlog if the main actor ever falls behind.

### Rendering

`ImageRenderer` at 3× on a 340 × 120 pt frame, average over 100 frames after a warm-up:

| View | Bars | Average per frame | 60 Hz budget |
| --- | --- | --- | --- |
| `WaveformView` (live, redrawn at 20 Hz) | 120 | ≈ 0.10 ms | 16.67 ms |
| `StaticWaveformView` (player) | 200 | ≈ 0.13 ms | 16.67 ms |

Both draw with a single `Canvas` pass instead of one view per bar, and the live waveform has its
own observable so only that view redraws at 20 Hz, not the whole recorder screen.

## What the numbers mean for the design

- **Bounded by construction, then verified.** The ring buffer (fixed capacity) and the
  downsampler (≤ `2 × bins + 1` values) make memory independent of recording length; the tests
  check that after every append instead of trusting the argument.
- **The audio thread is not the bottleneck.** Writing and metering cost a fraction of a percent of
  each buffer's duration, so no work needed to move off the real-time thread.
- **Rendering is not either.** Drawing both waveforms is two orders of magnitude under a frame,
  which justifies keeping them as plain `Canvas` views.

## Not measured yet

- Real-device CPU, energy and thermal behaviour during a multi-hour recording (needs Instruments on
  hardware).
- Disk-full and low-memory behaviour beyond what the error paths already handle.
