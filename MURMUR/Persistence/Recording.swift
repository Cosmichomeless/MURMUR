import Foundation
import SwiftData

/// The current version of the model. Older versions live in `Schema/` for migrations only.
typealias Recording = MurmurSchemaV2.Recording

extension Recording {
    var waveform: [Float] {
        get { WaveformCodec.decode(waveformData) }
        set { waveformData = WaveformCodec.encode(newValue) }
    }

    func fileURL(in store: RecordingFileStore) -> URL {
        store.fileURL(for: fileName)
    }
}
