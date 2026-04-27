import XCTest
@testable import Tagarela

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "tagarela.tests.preferences"
    private let dummyStyleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func test_defaults_match_designV1() {
        let store = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(store.refinerKind, .none)
        XCTAssertEqual(store.selectedStyleID, dummyStyleID)
        XCTAssertEqual(store.openAIModel, "gpt-5.4-mini")
        XCTAssertEqual(store.ollamaBaseURL, "http://localhost:11434")
        XCTAssertEqual(store.ollamaModel, "qwen3.5:9b-nvfp4")
        XCTAssertEqual(store.refinerTimeoutSec, 30)
        XCTAssertEqual(store.historyMaxItems, 200)
        XCTAssertEqual(store.historyMaxDays, 30)
        XCTAssertEqual(store.audioBoostMaxGain, 20.0)
    }

    func test_setRefinerKind_persistsAcrossInit() {
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.refinerKind = .ollama
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.refinerKind, .ollama)
    }

    func test_setSelectedStyleID_persistsAcrossInit() {
        let newID = UUID()
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.selectedStyleID = newID
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.selectedStyleID, newID)
    }

    func test_audioBoostMaxGain_clampedToRange() {
        let s = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s.audioBoostMaxGain = 100   // > 50
        XCTAssertEqual(s.audioBoostMaxGain, 50)
        s.audioBoostMaxGain = 0.1   // < 1
        XCTAssertEqual(s.audioBoostMaxGain, 1)
    }
}
