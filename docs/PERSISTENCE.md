# MURMUR — Persistence Design

Phase 3 of the roadmap: the SwiftData model, where files live and how metadata and audio stay
consistent. Architecture context: [ARCHITECTURE.md](ARCHITECTURE.md).

## Model

```text
Recording (SwiftData @Model)
├── id: UUID                  not enforced unique since schema V4 (CloudKit forbids it); the reconciler dedupes
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

## iCloud sync (optional, off by default)

Added in schema V4 for [#38](https://github.com/Cosmichomeless/MURMUR/issues/38). The user turns it
on in Settings; it applies at the next launch because the store is opened once.

A note travels in two halves, through two channels, both in the **user's own private iCloud**
(container `iCloud.com.cosmichomeless.murmur`). Nothing goes to a server of ours.

| Half | Channel | Notes |
| --- | --- | --- |
| Metadata (title, tags, transcript, waveform…) | SwiftData's CloudKit mirror (`ModelConfiguration(cloudKitDatabase: .private)`) | Needs a schema with no `unique` and every attribute defaulted, hence V4 |
| Audio (`<uuid>.m4a`) | `CloudKitAudioSync`: a `CKSyncEngine` over a custom zone, one `CKAsset` record per file, record name = file name | Not mirrorable by SwiftData; has its own sync state in `Application Support/Sync/` |

### Conflict rules

- **Audio is immutable.** A file is written once under a random UUID name and never edited, so it
  cannot conflict. If a name already exists locally, the existing file wins and the download is
  discarded (`RecordingFileStore.adoptDownloaded`: first writer wins, never overwrites, copied to a
  temporary file and renamed atomically).
- **Names from the cloud are untrusted.** Only `<UUID>.m4a` is accepted (`AudioSyncRules`), so a
  crafted record cannot write outside the recordings folder.
- **Delete wins over edit.** A deletion on any device removes the note and its audio everywhere.
- **Metadata is last-writer-wins per record**, resolved by SwiftData/CloudKit, not by the app. Two
  devices editing the same note's title at once keep the later write.
- **Duplicates.** Without a unique constraint two devices could end up with the same `id`; the
  reconciler keeps the oldest and deletes the extras.

### Metadata and audio arrive separately

Either half can be missing for a while without anything being wrong, so with sync on the
reconciler changes its rules:

- A `Recording` whose audio file is missing is **kept**, shown with a "not downloaded" indicator,
  and playable once the audio arrives (`SyncSettings.audioRevision` refreshes the views).
  Sharing its audio before then reports an error.
- A file with no `Recording` is kept for `syncOrphanGracePeriod` (7 days) in case its metadata
  has not arrived, and removed after that.
- With sync off the original rules apply (notes without audio are removed, orphans removed at once).

### Turning it off, and other edge cases

- Turning sync off stops sending and receiving. What is already on the device stays, and what is
  still in iCloud stays there. **Deleting a note while sync is off is not propagated**; turning it
  on again later can bring the note back from another device.
- Turning it on uploads the existing library once (audio backfill flagged in `UserDefaults`).
- If the cloud store cannot be opened the app opens the local store and tells the user
  (`SyncIssue.unavailable`) instead of failing to launch.
- No iCloud account: reported in Settings; nothing syncs. Full iCloud storage: new audio cannot be
  uploaded and Settings says so.
- A different iCloud account on the device: `CKSyncEngine` reports the account change and the
  audio sync state is reset, so the audio uploads again to the new account.
- Demo and test runs (`inMemory`) never touch CloudKit.

### Not verified

CloudKit has not been exercised against a real container: there is no registered container or
iCloud-signed build yet. Only the pure rules (names, adoption, reconciliation, repository
notifications) are covered by tests. See the limits in `docs/RELEASE_NOTES.md`.

## Testing

`MURMURTests/Persistence` covers the codec, the model round trip, the file store lifecycle and the
reconciler (orphans, missing files, temporary purge, untouched consistent library), all against an
in-memory container and a throwaway directory. `AudioSyncTests` covers the sync rules; the
migration tests open old stores with `cloudKitDatabase: .none` because the app now carries the
iCloud entitlement and the default would try to use CloudKit with the old schemas.
