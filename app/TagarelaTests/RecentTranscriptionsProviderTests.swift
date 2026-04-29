import XCTest
@testable import Tagarela

@MainActor
final class RecentTranscriptionsProviderTests: XCTestCase {
    private final class FakeStore: HistoryStore, @unchecked Sendable {
        var savedItems: [Transcription] = []
        var shouldThrow = false
        func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {}
        func recent(limit: Int) async throws -> [Transcription] {
            if shouldThrow { throw NSError(domain: "test", code: 0) }
            return Array(savedItems.prefix(limit))
        }
        func clearAll() async throws { savedItems.removeAll() }
    }

    func test_reload_callsRecentWithLimit5() async {
        let store = FakeStore()
        store.savedItems = (0..<10).map { i in
            Transcription(durationSeconds: Double(i),
                          rawText: "raw\(i)", refinedText: "ref\(i)",
                          refinerKind: "none", llmModelName: nil,
                          whisperModelName: "test", styleName: "test",
                          frontmostAppBundleID: nil)
        }
        let provider = RecentTranscriptionsProvider(store: store, limit: 5)
        await provider.reload()
        XCTAssertEqual(provider.recents.count, 5)
    }

    func test_reload_emptyStore_returnsEmpty() async {
        let provider = RecentTranscriptionsProvider(store: FakeStore(), limit: 5)
        await provider.reload()
        XCTAssertEqual(provider.recents.count, 0)
    }

    func test_reload_storeThrows_returnsEmpty() async {
        let store = FakeStore()
        store.shouldThrow = true
        let provider = RecentTranscriptionsProvider(store: store, limit: 5)
        await provider.reload()
        XCTAssertEqual(provider.recents.count, 0)
    }
}
