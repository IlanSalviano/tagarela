import Combine
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
        XCTAssertEqual(store.ollamaModel, "gemma4:e4b")
        XCTAssertEqual(store.refinerTimeoutSec, 60)
        XCTAssertEqual(store.historyMaxItems, 200)
        XCTAssertEqual(store.historyMaxDays, 30)
        XCTAssertEqual(store.audioBoostMaxGain, 20.0)
        XCTAssertEqual(store.openAIEndpoint, PreferencesDefaults.openAIEndpoint)
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
        s.setAudioBoostMaxGain(100)   // > 50
        XCTAssertEqual(s.audioBoostMaxGain, 50)
        s.setAudioBoostMaxGain(0.1)   // < 1
        XCTAssertEqual(s.audioBoostMaxGain, 1)
    }

    func test_audioBoostMaxGain_persistsAcrossInit() {
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.setAudioBoostMaxGain(7.5)
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.audioBoostMaxGain, 7.5, accuracy: 0.001)
    }

    func test_setOpenAIEndpoint_persistsAcrossInit() {
        let endpoint = OpenAIEndpoint(provider: .lmstudio,
                                       baseURL: URL(string: "http://localhost:1234/v1")!)
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.openAIEndpoint = endpoint
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.openAIEndpoint, endpoint)
    }

    func test_setHistoryMaxItems_clampsToMinimumOne() {
        let s = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s.setHistoryMaxItems(0)
        XCTAssertEqual(s.historyMaxItems, 1)
        s.setHistoryMaxItems(-100)
        XCTAssertEqual(s.historyMaxItems, 1)
        s.setHistoryMaxItems(500)
        XCTAssertEqual(s.historyMaxItems, 500)
    }

    func test_setHistoryMaxDays_clampsToMinimumOne() {
        let s = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s.setHistoryMaxDays(0)
        XCTAssertEqual(s.historyMaxDays, 1)
        s.setHistoryMaxDays(-7)
        XCTAssertEqual(s.historyMaxDays, 1)
        s.setHistoryMaxDays(60)
        XCTAssertEqual(s.historyMaxDays, 60)
    }

    func test_setRefinerKind_publishesToCombineSubscribers() {
        let s = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        var received: [RefinerKind] = []
        let exp = expectation(description: "publishes")
        exp.expectedFulfillmentCount = 2  // initial value + change

        let cancellable = s.$refinerKind.sink { kind in
            received.append(kind)
            exp.fulfill()
        }
        s.refinerKind = .openai
        wait(for: [exp], timeout: 1.0)
        cancellable.cancel()

        XCTAssertEqual(received, [.none, .openai])
    }
}
