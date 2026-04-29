import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class CustomStyleTests: XCTestCase {
    func test_init_setsDefaults() {
        let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        XCTAssertEqual(s.name, "x")
        XCTAssertEqual(s.systemPrompt, "y")
        XCTAssertTrue(s.appendCodeSwitching)
        XCTAssertEqual(s.createdAt.timeIntervalSinceNow, 0, accuracy: 1.0)
    }

    func test_asStyle_appendsCodeSwitchingWhenFlagOn() {
        let s = CustomStyle(name: "x", systemPrompt: "base", appendCodeSwitching: true)
        XCTAssertTrue(s.asStyle().systemPrompt.contains("code-switching") ||
                       s.asStyle().systemPrompt.contains("termos técnicos"))
    }

    func test_asStyle_withoutCodeSwitching_keepsDisciplinePrefix() {
        let s = CustomStyle(name: "x", systemPrompt: "base", appendCodeSwitching: false)
        let prompt = s.asStyle().systemPrompt
        // Discipline prefix sempre presente
        XCTAssertTrue(prompt.contains("NÃO responda"))
        XCTAssertTrue(prompt.contains("base"))
        // Sem code-switching
        XCTAssertFalse(prompt.contains("code-switching"))
        XCTAssertFalse(prompt.contains("termos técnicos"))
    }

    func test_asStyle_isBuiltInIsFalse() {
        let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: false)
        XCTAssertFalse(s.asStyle().isBuiltIn)
    }

    func test_asStyle_alwaysPrefixesRewriterDiscipline() {
        // Built-ins têm proteção embutida no system prompt; custom styles
        // dependem deste prefixo pra não virar chat assistant.
        let s1 = CustomStyle(name: "x", systemPrompt: "abc", appendCodeSwitching: false)
        let s2 = CustomStyle(name: "y", systemPrompt: "def", appendCodeSwitching: true)
        XCTAssertTrue(s1.asStyle().systemPrompt.hasPrefix("Você é um pós-processador"))
        XCTAssertTrue(s2.asStyle().systemPrompt.hasPrefix("Você é um pós-processador"))
    }
}
