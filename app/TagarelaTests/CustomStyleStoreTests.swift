import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class CustomStyleStoreTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Transcription.self, CustomStyle.self, configurations: config)
    }

    private func makeStore(_ container: ModelContainer) -> CustomStyleStoreLive {
        CustomStyleStoreLive(container: container) { _ in }
    }

    func test_create_emptyName_throws() async throws {
        let store = makeStore(try makeContainer())
        do {
            _ = try await store.create(name: "  ", systemPrompt: "p", appendCodeSwitching: false)
            XCTFail("expected throw")
        } catch CustomStyleStoreError.invalidInput {} catch { XCTFail("wrong: \(error)") }
    }

    func test_create_emptyPrompt_throws() async throws {
        let store = makeStore(try makeContainer())
        do {
            _ = try await store.create(name: "n", systemPrompt: "", appendCodeSwitching: false)
            XCTFail("expected throw")
        } catch CustomStyleStoreError.invalidInput {} catch { XCTFail("wrong: \(error)") }
    }

    func test_create_persists() async throws {
        let store = makeStore(try makeContainer())
        let s = try await store.create(name: "commits", systemPrompt: "...", appendCodeSwitching: true)
        await store.reload()
        XCTAssertEqual(store.styles.count, 1)
        XCTAssertEqual(store.styles.first?.id, s.id)
    }

    func test_update_changesUpdatedAt() async throws {
        let store = makeStore(try makeContainer())
        let s = try await store.create(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        let original = s.updatedAt
        try await Task.sleep(nanoseconds: 50_000_000)
        s.name = "x updated"
        try await store.update(s)
        XCTAssertGreaterThan(s.updatedAt, original)
    }

    func test_delete_callsCallbackWithDeletedID() async throws {
        let container = try makeContainer()
        nonisolated(unsafe) var capturedID: UUID?
        let store = CustomStyleStoreLive(container: container) { id in
            capturedID = id
        }
        let s = try await store.create(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        let originalID = s.id
        try await store.delete(s)
        XCTAssertEqual(capturedID, originalID)
        await store.reload()
        XCTAssertEqual(store.styles.count, 0)
    }

    func test_noop_returnsEmptyAndThrowsOnWrites() async throws {
        let store = CustomStyleStoreNoop()
        await store.reload()
        XCTAssertEqual(store.styles.count, 0)
        do {
            _ = try await store.create(name: "x", systemPrompt: "y", appendCodeSwitching: false)
            XCTFail("expected throw")
        } catch {}
    }
}
