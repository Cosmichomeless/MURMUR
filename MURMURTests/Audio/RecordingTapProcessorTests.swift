import AVFoundation
import Foundation
import Testing
@testable import MURMUR

struct RecordingTapProcessorTests {
    static let sampleRate = 44_100.0

    private static func sineBuffer(frames: AVAudioFrameCount, amplitude: Float) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            samples[i] = amplitude * sin(2 * .pi * 440 * Float(i) / Float(sampleRate))
        }
        return buffer
    }

    private func makeProcessor(in store: TestStore)
        throws -> (RecordingTapProcessor, URL, AsyncThrowingStream<RecorderSample, Error>)
    {
        let url = store.fileStore.makeTemporaryURL()
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: Self.sampleRate,
                AVNumberOfChannelsKey: 1,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let (stream, continuation) = AsyncThrowingStream<RecorderSample, Error>.makeStream()
        return (RecordingTapProcessor(file: file, sampleRate: Self.sampleRate, continuation: continuation), url, stream)
    }

    @Test func writesAReadableFileWithTheRecordedDuration() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (processor, url, _) = try makeProcessor(in: store)

        // 1 second of audio in 1024-frame buffers, like the engine tap.
        var remaining = Int(Self.sampleRate)
        while remaining > 0 {
            let frames = AVAudioFrameCount(min(1024, remaining))
            processor.process(Self.sineBuffer(frames: frames, amplitude: 0.5))
            remaining -= Int(frames)
        }
        let frames = processor.finish()

        #expect(frames == AVAudioFramePosition(Self.sampleRate))
        let read = try AVAudioFile(forReading: url)
        let duration = Double(read.length) / read.processingFormat.sampleRate
        #expect(abs(duration - 1.0) < 0.1) // AAC adds priming/padding frames
    }

    @Test func emitsAboutTwentySamplesPerSecondWithIncreasingDuration() async throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (processor, _, stream) = try makeProcessor(in: store)

        for _ in 0..<43 { // ≈ 1 s
            processor.process(Self.sineBuffer(frames: 1024, amplitude: 0.5))
        }
        _ = processor.finish()

        var samples: [RecorderSample] = []
        for try await sample in stream { samples.append(sample) }

        #expect((15...22).contains(samples.count))
        #expect(samples.map(\.duration) == samples.map(\.duration).sorted())
        #expect(samples.allSatisfy { (0...1).contains($0.level) })
        #expect(samples.last!.level > 0.5)
    }

    @Test func pausedBuffersAreNotWritten() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (processor, _, _) = try makeProcessor(in: store)

        processor.process(Self.sineBuffer(frames: 1024, amplitude: 0.5))
        processor.setPaused(true)
        processor.process(Self.sineBuffer(frames: 1024, amplitude: 0.5))
        processor.setPaused(false)
        processor.process(Self.sineBuffer(frames: 1024, amplitude: 0.5))

        #expect(processor.finish() == 2048)
    }

    @Test func buffersAfterFinishAreIgnored() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let (processor, _, _) = try makeProcessor(in: store)

        processor.process(Self.sineBuffer(frames: 1024, amplitude: 0.5))
        _ = processor.finish()
        processor.process(Self.sineBuffer(frames: 1024, amplitude: 0.5))

        #expect(processor.framesWritten == 1024)
    }
}
