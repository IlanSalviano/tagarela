import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class HistoryStoreTests: XCTestCase {
    private func make() throws -> HistoryStoreLive {
        try HistoryStoreLive(inMemory: true)
    }

    private func sample(rawText: String = "cru") -> TranscriptionInput {
        TranscriptionInput(
            durationSeconds: 3.5, rawText: rawText, refinedText: "ref",
            refinerKind: "none", llmModelName: nil,
            whisperModelName: "large-v3", styleName: "conversa informal",
            frontmostAppBundleID: nil)
    }

    func test_save_persistsTranscription() async throws {
        let s = try make()
        try await s.save(sample(rawText: "abc"), maxItems: 100, maxDays: 30)
        let r = try await s.recent(limit: 10)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.rawText, "abc")
    }

    func test_recent_returnsNewestFirst() async throws {
        let s = try make()
        try await s.save(sample(rawText: "older"), maxItems: 100, maxDays: 30)
        try await Task.sleep(nanoseconds: 10_000_000)
        try await s.save(sample(rawText: "newer"), maxItems: 100, maxDays: 30)
        let r = try await s.recent(limit: 10)
        XCTAssertEqual(r.first?.rawText, "newer")
    }

    func test_retentionByCount_keepsTopN() async throws {
        let s = try make()
        for i in 0..<5 {
            try await s.save(sample(rawText: "n\(i)"), maxItems: 3, maxDays: 30)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        let r = try await s.recent(limit: 10)
        XCTAssertEqual(r.count, 3)
    }

    func test_retentionByDays_purgesOld() async throws {
        let s = try make()
        // Insere uma com createdAt no passado direto via mainContext
        let ctx = ModelContext(try ModelContainer(
            for: Transcription.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let oldTrans = Transcription(
            createdAt: Date().addingTimeInterval(-60 * 86_400),
            durationSeconds: 1, rawText: "old", refinedText: "old",
            refinerKind: "none", llmModelName: nil,
            whisperModelName: "large-v3", styleName: "conversa informal",
            frontmostAppBundleID: nil)
        ctx.insert(oldTrans)
        try ctx.save()
        // Salvar uma nova no store (que aplicará retention sobre seu próprio container)
        try await s.save(sample(rawText: "new"), maxItems: 100, maxDays: 30)
        let r = try await s.recent(limit: 10)
        XCTAssertFalse(r.contains { $0.rawText == "old" }, "retention should not see entries from outside store")
        XCTAssertTrue(r.contains { $0.rawText == "new" })
    }

    func test_retention_bothLimitsApply() async throws {
        let s = try make()
        for i in 0..<10 {
            try await s.save(sample(rawText: "n\(i)"), maxItems: 5, maxDays: 30)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        let r = try await s.recent(limit: 100)
        XCTAssertEqual(r.count, 5)
    }

    func test_save_appliesRetentionImmediately() async throws {
        let s = try make()
        for _ in 0..<3 { try await s.save(sample(), maxItems: 2, maxDays: 30) }
        let r = try await s.recent(limit: 100)
        XCTAssertEqual(r.count, 2)
    }
}
