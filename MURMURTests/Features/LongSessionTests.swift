import AVFoundation
import Foundation
import SwiftUI
import Testing
@testable import MURMUR

/// Long recordings and heavy screens. Each test prints `METRIC` lines (see `ResourceProbe`) and
/// asserts generous bounds: tight enough to catch an accidental O(n) growth or a 10x slowdown,
/// loose enough not to flake on a busy CI machine.
@MainActor
@Suite(.serialized)
struct LongSessionTests {
    private func format(_ value: Double, _ digits: Int = 2) -> String {
        String(format: "%.\(digits)f", value) // not locale-aware on purpose: METRIC lines are parsed
    }

    // MARK: - Recorder view model

    @Test func anHourOfMeterSamplesKeepsTheViewModelBounded() async {
        let recorder = FakeAudioRecorder()
        let model = RecorderViewModel(
            access: MicrophoneAccess(session: FakeAudioSession(permission: .granted)),
            recorder: recorder,
            save: { _ in }
        )
        await model.start()

        let samples = 20 * 60 * 60 // one hour at 20 Hz
        let warmUp = samples / 6 // first 10 minutes: caches, lazy allocations, code paging
        var residentAfterWarmUp = 0
        let cpuBefore = ResourceProbe.cpuSeconds()
        let start = ContinuousClock.now

        for index in 1...samples {
            recorder.emit(duration: Double(index) * RecordingTapProcessor.sampleWindow, level: Float(index % 10) / 10)
            if index % 16 == 0 { await Task.yield() } // let the consumer keep up like real time would
            if index == warmUp { residentAfterWarmUp = ResourceProbe.residentBytes() }
        }
        for _ in 0..<50 { await Task.yield() }

        let wall = start.duration(to: .now)
        let wallSeconds = Double(wall.components.seconds) + Double(wall.components.attoseconds) / 1e18
        // Steady state: what the remaining 50 minutes added on top of the warmed-up process.
        let growth = Double(ResourceProbe.residentBytes() - residentAfterWarmUp) / 1_048_576
        ResourceProbe.report("view-model-1h", [
            "samples": "\(samples)",
            "wall_s": format(wallSeconds),
            "cpu_s": format(ResourceProbe.cpuSeconds() - cpuBefore),
            "steady_state_growth_mb": format(growth),
            "live_bars": "\(model.waveform.count)",
        ])

        #expect(model.waveform.count == LiveWaveform.defaultCapacity)
        #expect(model.elapsed == Double(samples) * RecordingTapProcessor.sampleWindow)
        #expect(growth < 20, "50 more minutes of samples must not accumulate memory")
        #expect(wallSeconds < 30)
    }

    // MARK: - Capture path

    /// Pushes ten minutes of real audio through the tap processor into an AAC file, the same path
    /// the audio thread runs, as fast as the machine allows.
    @Test func tenMinutesOfAudioThroughTheTapIsMuchFasterThanRealTime() throws {
        let sampleRate = 44_100.0
        let framesPerBuffer: AVAudioFrameCount = 1024
        let seconds = 600.0
        let buffers = Int(seconds * sampleRate / Double(framesPerBuffer))

        let store = TestStore()
        defer { store.cleanUp() }
        let url = store.fileStore.makeTemporaryURL()
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let (stream, continuation) = AsyncThrowingStream<RecorderSample, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        _ = stream
        let processor = RecordingTapProcessor(file: file, sampleRate: sampleRate, continuation: continuation)

        let audioFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: framesPerBuffer))
        buffer.frameLength = framesPerBuffer
        let channel = try #require(buffer.floatChannelData?[0])
        for frame in 0..<Int(framesPerBuffer) {
            channel[frame] = 0.4 * sin(Float(frame) * 2 * .pi * 440 / Float(sampleRate))
        }

        let usage = ResourceProbe.measure {
            for _ in 0..<buffers { processor.process(buffer) }
        }
        let frames = processor.finish()

        let waveform = processor.waveform
        let fileBytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        let realTimeFactor = seconds / usage.wallSeconds
        let perBufferMicroseconds = usage.wallSeconds / Double(buffers) * 1e6
        let budgetMicroseconds = Double(framesPerBuffer) / sampleRate * 1e6
        ResourceProbe.report("tap-10min", [
            "buffers": "\(buffers)",
            "wall_s": format(usage.wallSeconds),
            "cpu_s": format(usage.cpuSeconds),
            "realtime_factor": format(realTimeFactor, 1),
            "per_buffer_us": format(perBufferMicroseconds, 1),
            "buffer_budget_us": format(budgetMicroseconds, 0),
            "resident_growth_mb": format(usage.residentGrowthMB),
            "file_kb": "\(fileBytes / 1024)",
            "waveform_bins": "\(waveform.count)",
        ])

        #expect(frames == AVAudioFramePosition(buffers) * AVAudioFramePosition(framesPerBuffer))
        #expect(waveform.count <= 2 * RecordingTapProcessor.waveformBinCount + 1)
        #expect(realTimeFactor > 5, "capture must run well faster than real time")
        #expect(usage.residentGrowthMB < 50, "memory must not follow the recording length")
    }

    // MARK: - Rendering

    private func averageRenderMilliseconds(frames: Int, make: (Int) -> some View) -> Double {
        let start = ContinuousClock.now
        for frame in 0..<frames {
            let renderer = ImageRenderer(content: make(frame).frame(width: 340, height: 120))
            renderer.scale = 3
            _ = renderer.cgImage
        }
        let elapsed = start.duration(to: .now)
        let total = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        return total / Double(frames)
    }

    @Test func theLiveWaveformRendersWellInsideAFrameBudget() {
        let waveform = LiveWaveform()
        for index in 0..<LiveWaveform.defaultCapacity { waveform.append(Float(index % 10) / 10) }
        let frames = 100

        _ = averageRenderMilliseconds(frames: 3) { _ in WaveformView(waveform: waveform) } // warm-up
        let residentBefore = ResourceProbe.residentBytes()
        let average = averageRenderMilliseconds(frames: frames) { frame in
            waveform.append(Float(frame % 10) / 10)
            return WaveformView(waveform: waveform)
        }
        let growth = Double(ResourceProbe.residentBytes() - residentBefore) / 1_048_576
        ResourceProbe.report("render-live-waveform", [
            "bars": "\(waveform.count)",
            "frames": "\(frames)",
            "avg_ms": format(average),
            "budget_ms_60hz": "16.67",
            "resident_growth_mb": format(growth),
        ])

        #expect(average < 16.67)
    }

    @Test func aFinishedWaveformRendersWellInsideAFrameBudget() {
        let levels = (0..<(2 * RecordingTapProcessor.waveformBinCount)).map { Float($0 % 10) / 10 }
        let frames = 100

        _ = averageRenderMilliseconds(frames: 3) { _ in StaticWaveformView(levels: levels) } // warm-up
        let average = averageRenderMilliseconds(frames: frames) { frame in
            StaticWaveformView(levels: levels, progress: Double(frame) / Double(frames))
        }
        ResourceProbe.report("render-static-waveform", [
            "bars": "\(levels.count)",
            "frames": "\(frames)",
            "avg_ms": format(average),
            "budget_ms_60hz": "16.67",
        ])

        #expect(average < 16.67)
    }
}
