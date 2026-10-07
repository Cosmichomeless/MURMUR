import Foundation
import SwiftData
import Testing
@testable import MURMUR

struct RecordingReconciliationPlanTests {
    @Test func consistentStateYieldsAnEmptyPlan() {
        let id = UUID()
        let plan = RecordingReconciliation.plan(storedFileNames: ["a.m4a"], records: [(id, "a.m4a")])
        #expect(plan.isConsistent)
    }

    @Test func unreferencedFilesAreOrphans() {
        let plan = RecordingReconciliation.plan(storedFileNames: ["a.m4a", "b.m4a"], records: [(UUID(), "a.m4a")])
        #expect(plan.orphanFiles == ["b.m4a"])
        #expect(plan.recordingsMissingFile.isEmpty)
    }

    @Test func recordsWithoutFilesAreReported() {
        let id = UUID()
        let plan = RecordingReconciliation.plan(storedFileNames: [], records: [(id, "gone.m4a")])
        #expect(plan.recordingsMissingFile == [id])
        #expect(plan.orphanFiles.isEmpty)
    }
}

@MainActor
struct RecordingReconcilerTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try PersistenceController.makeContainer(inMemory: true))
    }

    @Test func removesOrphanFilesAndKeepsReferencedOnes() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let context = try makeContext()
        let kept = store.writeRecordingFile()
        let orphan = store.writeRecordingFile()
        context.insert(Recording(title: "kept", fileName: kept, duration: 1))
        try context.save()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore).run()

        #expect(report.removedOrphanFiles == 1)
        #expect(store.fileStore.exists(fileName: kept))
        #expect(!store.fileStore.exists(fileName: orphan))
    }

    @Test func removesRecordingsWhoseFileIsMissing() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let context = try makeContext()
        let kept = store.writeRecordingFile()
        context.insert(Recording(title: "kept", fileName: kept, duration: 1))
        context.insert(Recording(title: "broken", fileName: "missing.m4a", duration: 1))
        try context.save()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore).run()

        #expect(report.removedRecordingsMissingFile == 1)
        let remaining = try context.fetch(FetchDescriptor<Recording>())
        #expect(remaining.map(\.title) == ["kept"])
    }

    @Test func purgesLeftoverTemporaryCaptures() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let context = try makeContext()
        _ = store.writeTemporaryFile()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore).run()

        #expect(report.purgedTemporaryFiles == 1)
    }

    @Test func consistentLibraryIsLeftUntouched() throws {
        let store = TestStore()
        defer { store.cleanUp() }
        let context = try makeContext()
        let name = store.writeRecordingFile()
        context.insert(Recording(title: "ok", fileName: name, duration: 1))
        try context.save()

        let report = try RecordingReconciler(context: context, fileStore: store.fileStore).run()

        #expect(report == ReconciliationReport(removedOrphanFiles: 0, removedRecordingsMissingFile: 0, purgedTemporaryFiles: 0))
        #expect(try context.fetch(FetchDescriptor<Recording>()).count == 1)
        #expect(store.fileStore.exists(fileName: name))
    }
}
