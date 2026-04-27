import XCTest
@testable import Tagarela

@MainActor
final class RefinerFactoryTests: XCTestCase {
    private var prefs: PreferencesStore!
    private let suite = "tagarela.tests.refinerfactory"

    override func setUp() async throws {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        prefs = PreferencesStore(defaults: defaults, defaultStyleID: BuiltInStyles.defaultStyleID)
    }

    private func makeFactory(openAI: @escaping () -> OpenAIRefiner = { fatalError("openAI not expected") },
                             ollama: @escaping () -> OllamaRefiner = { fatalError("ollama not expected") })
    -> RefinerFactory {
        RefinerFactory(prefs: prefs, openAI: openAI, ollama: ollama)
    }

    func test_currentWithRefinerKindNone_returnsIdentity() {
        prefs.refinerKind = .none
        let (refiner, _) = makeFactory().current()
        XCTAssertEqual(refiner.kind, .none)
    }

    func test_currentWithStyleCru_returnsIdentityRegardlessOfKind() {
        prefs.refinerKind = .openai // mesmo com openai, cru deve forçar identity
        prefs.selectedStyleID = BuiltInStyles.cruSemReescrita.id
        let (refiner, style) = makeFactory().current()
        XCTAssertEqual(refiner.kind, .none)
        XCTAssertEqual(style.id, BuiltInStyles.cruSemReescrita.id)
    }

    func test_currentWithRefinerKindOpenai_returnsOpenAI() {
        prefs.refinerKind = .openai
        let openai = OpenAIRefiner(session: MockURLProtocol.session(),
                                   keychain: FakeKeychainService(initial: "sk"),
                                   model: "gpt-5.4-mini",
                                   timeoutSec: 30)
        let (refiner, _) = makeFactory(openAI: { openai }).current()
        XCTAssertEqual(refiner.kind, .openai)
    }

    func test_currentWithRefinerKindOllama_returnsOllama() {
        prefs.refinerKind = .ollama
        let baseURL = URL(string: "http://localhost:11434")!
        let session = MockURLProtocol.session()
        let hc = OllamaHealthChecker(session: session, baseURL: baseURL)
        let ollama = OllamaRefiner(session: session, baseURL: baseURL,
                                   model: "qwen3.5:9b-nvfp4", timeoutSec: 30, healthChecker: hc)
        let (refiner, _) = makeFactory(ollama: { ollama }).current()
        XCTAssertEqual(refiner.kind, .ollama)
    }
}
