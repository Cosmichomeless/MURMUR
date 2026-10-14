import Foundation
import SwiftData
import Testing
@testable import MURMUR

/// A user updating from a build that had no transcripts must keep every note.
@MainActor
struct SchemaMigrationTests {
    @Test func aVersionOneStoreOpensWithTheCurrentSchemaAndKeepsItsRecordings() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let url = store.root.appendingPathComponent("v1.sqlite")
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let waveform: [Float] = [0.1, 0.5, 0.9]

        do {
            let schema = Schema(versionedSchema: MurmurSchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            container.mainContext.insert(MurmurSchemaV1.Recording(
                id: id, title: "Old note", fileName: "old.m4a", duration: 42, createdAt: date,
                waveformData: WaveformCodec.encode(waveform)
            ))
            try container.mainContext.save()
        }

        let migrated = try PersistenceController.makeContainer(storeURL: url)
        let recordings = try migrated.mainContext.fetch(FetchDescriptor<Recording>())
        let recording = try #require(recordings.first)
        #expect(recordings.count == 1)
        #expect(recording.id == id)
        #expect(recording.title == "Old note")
        #expect(recording.fileName == "old.m4a")
        #expect(recording.duration == 42)
        #expect(recording.createdAt == date)
        #expect(recording.waveform == waveform)
        // New properties start out empty, never missing.
        #expect(recording.transcriptText == nil)
        #expect(recording.transcriptionStatus == .notRequested)
        #expect(!recording.isTranscriptEdited)
    }

    @Test func aMigratedStoreAcceptsATranscript() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let url = store.root.appendingPathComponent("v1.sqlite")
        do {
            let schema = Schema(versionedSchema: MurmurSchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            container.mainContext.insert(MurmurSchemaV1.Recording(title: "Old", fileName: "o.m4a", duration: 1))
            try container.mainContext.save()
        }

        let migrated = try PersistenceController.makeContainer(storeURL: url)
        let repository = RecordingRepository(context: migrated.mainContext, fileStore: store.fileStore)
        let recording = try #require(try migrated.mainContext.fetch(FetchDescriptor<Recording>()).first)
        try repository.apply(Transcript(text: "ok", segments: [], localeIdentifier: "en-US"), to: recording)

        #expect(try migrated.mainContext.fetch(FetchDescriptor<Recording>()).first?.transcriptText == "ok")
    }

    @Test func aVersionTwoStoreGainsTagsAndKeepsItsTranscript() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let url = store.root.appendingPathComponent("v2.sqlite")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: MurmurSchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            let old = MurmurSchemaV2.Recording(id: id, title: "Transcribed", fileName: "t.m4a", duration: 9)
            old.transcriptText = "hello there"
            old.transcriptionStatusRaw = TranscriptionStatus.completed.rawValue
            container.mainContext.insert(old)
            try container.mainContext.save()
        }

        let migrated = try PersistenceController.makeContainer(storeURL: url)
        let recording = try #require(try migrated.mainContext.fetch(FetchDescriptor<Recording>()).first)
        #expect(recording.id == id)
        #expect(recording.title == "Transcribed")
        #expect(recording.transcriptText == "hello there")
        #expect(recording.transcriptionStatus == .completed)
        #expect(recording.tags.isEmpty)
    }

    @Test func aVersionThreeStoreLosesItsUniqueConstraintAndKeepsEverything() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let url = store.root.appendingPathComponent("v3.sqlite")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: MurmurSchemaV3.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            let old = MurmurSchemaV3.Recording(id: id, title: "Tagged", fileName: "g.m4a", duration: 12, waveform: [0.2, 0.4])
            old.transcriptText = "some words"
            old.tagsRaw = "work\nideas"
            container.mainContext.insert(old)
            try container.mainContext.save()
        }

        let migrated = try PersistenceController.makeContainer(storeURL: url)
        let recording = try #require(try migrated.mainContext.fetch(FetchDescriptor<Recording>()).first)
        #expect(recording.id == id)
        #expect(recording.title == "Tagged")
        #expect(recording.fileName == "g.m4a")
        #expect(recording.transcriptText == "some words")
        #expect(recording.tags == ["work", "ideas"])
        #expect(recording.waveform == [0.2, 0.4])
    }
}
