import XCTest
@testable import Tagarela

@MainActor
final class RefinerFactoryTests: XCTestCase {
    private var prefs: PreferencesStore!
    private let suite = "tagarela.tests.refinerfactory"

    // Minimal fake store for tests that only need built-in styles.
    private final class FakeCustomStore: CustomStyleStore, ObservableObject {
        var styles: [CustomStyle] = []
        func reload() async {}
        func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle { fatalError() }
        func update(_ style: CustomStyle) async throws { fatalError() }
        func delete(_ style: CustomStyle) async throws { fatalError() }
    }

    override func setUp() async throws {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        prefs = PreferencesStore(defaults: defaults, defaultStyleID: BuiltInStyles.defaultStyleID)
    }

    private func makeFactory(openAI: @escaping () -> OpenAIRefiner = { fatalError("openAI not expected") },
                             ollama: @escaping () -> OllamaRefiner = { fatalError("ollama not expected") })
    -> RefinerFactory {
        let styleProvider = StyleProvider(customStore: FakeCustomStore())
        return RefinerFactory(prefs: prefs, styleProvider: styleProvider, openAI: openAI, ollama: ollama)
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
                                   baseURL: URL(string: "https://api.openai.com/v1")!,
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

    func test_factory_passesBaseURLFromPrefs_toOpenAIRefiner() {
        prefs.openAIEndpoint = OpenAIEndpoint(
            provider: .lmstudio,
            baseURL: URL(string: "http://localhost:1234/v1")!)
        nonisolated(unsafe) var seenBaseURL: URL?
        let factory = RefinerFactory(
            prefs: prefs,
            styleProvider: StyleProvider(customStore: FakeCustomStore()),
            openAI: { [weak self] in
                guard let self else { fatalError() }
                seenBaseURL = self.prefs.openAIEndpoint.baseURL
                return OpenAIRefiner(session: .shared,
                                     keychain: FakeKeychainService(initial: "sk"),
                                     baseURL: self.prefs.openAIEndpoint.baseURL,
                                     model: "x",
                                     timeoutSec: 30)
            },
            ollama: { fatalError("não chamado") })
        prefs.refinerKind = .openai
        _ = factory.current()
        XCTAssertEqual(seenBaseURL, URL(string: "http://localhost:1234/v1"))
    }
}
