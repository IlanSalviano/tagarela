import XCTest
@testable import Tagarela

final class InitialPromptBuilderTests: XCTestCase {
    func test_emptyVocab_returnsBaseContext() {
        let s = InitialPromptBuilder.build(vocab: [])
        XCTAssertTrue(s.contains("português brasileiro"))
        XCTAssertFalse(s.contains("Termos esperados"))
    }

    func test_withVocab_listsTerms() {
        let s = InitialPromptBuilder.build(vocab: ["Postgres", "deploy", "Kubernetes"])
        XCTAssertTrue(s.contains("Postgres"))
        XCTAssertTrue(s.contains("deploy"))
        XCTAssertTrue(s.contains("Kubernetes"))
    }

    func test_truncatesVocabAtTokenLimit() {
        let huge = (0..<500).map { "termo\($0)" }
        let s = InitialPromptBuilder.build(vocab: huge)
        // Whisper aceita ~224 tokens; cortamos antes disso.
        XCTAssertLessThan(s.count, 1500)
    }
}
