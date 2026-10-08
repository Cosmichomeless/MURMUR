# MURMUR — Persistence Design

Phase 3 of the roadmap: the SwiftData model, where files live and how metadata and audio stay
consistent. Architecture context: [ARCHITECTURE.md](ARCHITECTURE.md).

## Model

```text
Recording (SwiftData @Model)
├── id: UUID                  unique
├── title: String
├── fileName: String          file name inside the recordings directory (not an absolute URL)
├── duration: TimeInterval    seconds, from frames written
├── createdAt: Date
└── waveformData: Data        encoded peak envelope, bounded size (WaveformCodec)
```

Decisions:

- **`fileName` instead of `fileURL`.** The original sketch in [PROJECT.md](PROJECT.md) lists `fileURL`. An absolute URL is invalid
  after a reinstall, an update or a simulator reset because the container path changes. The model
  stores the name and `fileURL(in:)` resolves it against `RecordingFileStore`.
- **`waveformData` as `Data`.** The envelope is a flat `[Float]` of at most a few hundred values;
  encoding it as bytes keeps the schema trivial and avoids a child entity.
- **No cascade to files.** SwiftData does not know about the file system. Deleting the file is an
  explicit step of the repository (see below).

## File locations

| Directory | Purpose | Lifetime |
| --- | --- | --- |
| `tmp/Recording/` | Capture in progress (`<uuid>.m4a`) | Disposable; purged at launch |
| `Application Support/Recordings/` | Finished recordings (`<uuid>.m4a`) | Until the user deletes the note |

- Both are on the same volume, so moving a finished capture is an atomic rename.
- `Application Support` is backed up with the device and is not visible in the Files app.
- Files keep the default data-protection class (*complete until first user authentication*), so
  recording can continue while the device is locked. A stricter class would stop background capture.
- File names are random UUIDs, never derived from the title, so titles can be anything.

## Order of operations

The invariant to protect: **a `Recording` never points to a missing file.** A file without a
`Recording` (an orphan) is tolerated temporarily because it is harmless and reconcilable.

### Save (finished capture → library)

| Step | Action | If it fails / the app dies here |
| --- | --- | --- |
| 1 | `commit`: rename `tmp/…` → `Recordings/<uuid>.m4a` | Nothing changed; temp file is purged at next launch |
| 2 | Insert `Recording` and `context.save()` | Roll back by deleting the file from step 1; if the process dies between 1 and 2 the file is an orphan and is removed by reconciliation |

### Delete

| Step | Action | If it fails / the app dies here |
| --- | --- | --- |
| 1 | Delete `Recording` and `context.save()` | Roll back the context; nothing was touched, the user can retry |
| 2 | Remove the audio file | The file is an orphan; reconciliation removes it at next launch |

Metadata goes first on delete and last on save, which is exactly what keeps the invariant: at every
instant the set of `Recording`s is a subset of the files on disk.

## Reconciliation

`RecordingReconciler.run()` executes once at launch, before any UI can save or delete:

1. Compare the files in `Recordings/` with the `fileName`s in the store (`RecordingReconciliation.plan`).
2. Delete `Recording`s whose file is missing (removed outside the app; they cannot be played).
3. Delete orphan files (leftovers of a crash between steps).
4. Purge `tmp/Recording/` (an unfinished AAC file has no valid header and cannot be recovered).

Safety rules:

- It reads both sides completely before mutating anything. A failed fetch or directory listing
  throws and deletes nothing, so a transient error cannot wipe the library.
- It never runs while a capture or a save could be in flight.
- Only files with the `.m4a` extension are considered.

## Testing

`MURMURTests/Persistence` covers the codec, the model round trip, the file store lifecycle and the
reconciler (orphans, missing files, temporary purge, untouched consistent library), all against an
in-memory container and a throwaway directory.
