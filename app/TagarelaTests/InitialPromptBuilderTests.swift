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

    func test_truncatesVocabAtCharFallback() {
        let huge = (0..<500).map { "termo\($0)" }
        let s = InitialPromptBuilder.build(vocab: huge)
        // Sem tokenCount, fallback char-based (pessimista 3 chars/token).
        XCTAssertLessThanOrEqual(s.count, InitialPromptBuilder.maxChars)
    }

    func test_truncatesVocabWithTokenCounter() {
        let huge = (0..<500).map { "termo\($0)" }
        // Tokenizer fake: 1 token a cada 3 chars (pessimista).
        let s = InitialPromptBuilder.build(vocab: huge, tokenCount: { $0.count / 3 })
        XCTAssertLessThanOrEqual(s.count / 3, InitialPromptBuilder.maxTokens)
    }
}
