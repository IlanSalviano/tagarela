import XCTest
@testable import Tagarela

final class WhisperModelStoreTests: XCTestCase {
    var tempDir: URL!
    var store: WhisperModelStoreLive!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperStoreTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = WhisperModelStoreLive(rootDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_isDownloaded_returnsFalseWhenAbsent() {
        XCTAssertFalse(store.isDownloaded("large-v3-turbo"))
    }

    func test_isDownloaded_returnsTrueAfterFakeContent() throws {
        let modelDir = tempDir.appendingPathComponent("openai_whisper-large-v3-turbo")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data([0xCA, 0xFE]).write(to: modelDir.appendingPathComponent("dummy.bin"))
        XCTAssertTrue(store.isDownloaded("large-v3-turbo"))
    }

    func test_sizeOnDisk_returnsBytes() throws {
        let modelDir = tempDir.appendingPathComponent("openai_whisper-medium")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: 1024).write(to: modelDir.appendingPathComponent("a.bin"))
        try Data(repeating: 0xCD, count: 2048).write(to: modelDir.appendingPathComponent("b.bin"))
        XCTAssertEqual(store.sizeOnDisk("medium"), 1024 + 2048)
    }

    func test_sizeOnDisk_recursesIntoSubdirectories() throws {
        // WhisperKit layout real tem subdirs (*.mlmodelc/coremldata.bin etc.).
        // Locks the enumerator's recursion behavior contra refator silencioso.
        let modelDir = tempDir.appendingPathComponent("openai_whisper-large-v3")
        let nested = modelDir.appendingPathComponent("AudioEncoder.mlmodelc")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 512).write(to: modelDir.appendingPathComponent("config.json"))
        try Data(repeating: 0, count: 1024).write(to: nested.appendingPathComponent("coremldata.bin"))
        XCTAssertEqual(store.sizeOnDisk("large-v3"), 512 + 1024)
    }

    func test_sizeOnDisk_returnsNilWhenAbsent() {
        XCTAssertNil(store.sizeOnDisk("large-v3"))
    }

    func test_delete_removesDirectory() async throws {
        let modelDir = tempDir.appendingPathComponent("openai_whisper-large-v3")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data([0x01]).write(to: modelDir.appendingPathComponent("dummy.bin"))
        XCTAssertTrue(store.isDownloaded("large-v3"))

        try await store.delete("large-v3")
        XCTAssertFalse(store.isDownloaded("large-v3"))
    }

    func test_delete_throwsWhenAbsent() async {
        do {
            try await store.delete("nonexistent")
            XCTFail("expected throw")
        } catch WhisperModelStoreError.notFound {
            // ok
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}
