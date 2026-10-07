import Foundation
import SwiftData

/// Metadata of one saved voice note. The audio itself lives in a file managed by
/// `RecordingFileStore`; this model only stores its *name*.
///
/// The file is referenced by name rather than by absolute URL because the app container path
/// changes between installs, updates and simulators. `fileURL(in:)` resolves the current location.
@Model
final class Recording {
    @Attribute(.unique) var id: UUID
    var title: String
    /// File name inside `RecordingFileStore.recordingsDirectory`, e.g. `3F2A….m4a`.
    var fileName: String
    var duration: TimeInterval
    var createdAt: Date
    /// Encoded peak envelope (see `WaveformCodec`). Bounded in size.
    var waveformData: Data

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        duration: TimeInterval,
        createdAt: Date = .now,
        waveform: [Float] = []
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.waveformData = WaveformCodec.encode(waveform)
    }

    var waveform: [Float] {
        get { WaveformCodec.decode(waveformData) }
        set { waveformData = WaveformCodec.encode(newValue) }
    }

    func fileURL(in store: RecordingFileStore) -> URL {
        store.fileURL(for: fileName)
    }
}
