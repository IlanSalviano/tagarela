import AppKit
import XCTest
@testable import Tagarela

/// Usam um `NSPasteboard` nomeado próprio, não o `general` — assim não mexem no
/// clipboard de quem estiver rodando a suíte.
final class InjectorTests: XCTestCase {
    private var board: NSPasteboard!

    override func setUp() {
        super.setUp()
        board = NSPasteboard(name: .init("com.tagarela.tests.\(UUID().uuidString)"))
        board.clearContents()
    }

    override func tearDown() {
        board.releaseGlobally()
        board = nil
        super.tearDown()
    }

    /// S3 da auditoria: `AXIsProcessTrusted()` era checado **antes** da escrita,
    /// então com a Acessibilidade caída o ditado sumia inteiro — não colava, não
    /// ficava no clipboard e (com a ordem antiga) nem entrava no histórico.
    func test_textReachesPasteboardEvenWhenAccessibilityDenied() async {
        let injector = InjectorLive(axTrusted: { false }, pasteboard: board)

        do {
            _ = try await injector.inject(text: "ditado importante")
            XCTFail("deveria lançar accessibilityDenied")
        } catch {
            XCTAssertEqual(error as? InjectionError, .accessibilityDenied)
        }

        XCTAssertEqual(board.string(forType: .string), "ditado importante",
                       "o ditado tem que sobrar na área de transferência")
    }

    func test_restoreSkippedWhenClipboardChanged() async throws {
        board.declareTypes([.string], owner: nil)
        board.setString("conteúdo anterior", forType: .string)

        let injector = InjectorLive(restoreDelayNanoseconds: 50_000_000,
                                    axTrusted: { true },
                                    pasteboard: board)
        _ = try await injector.inject(text: "ditado")

        // Alguém copia outra coisa antes da restauração acontecer.
        board.clearContents()
        board.declareTypes([.string], owner: nil)
        board.setString("copiei outra coisa", forType: .string)

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(board.string(forType: .string), "copiei outra coisa",
                       "restauração não pode atropelar o que o usuário copiou depois")
    }

    func test_restoreHappensWhenNobodyTouchedTheClipboard() async throws {
        board.declareTypes([.string], owner: nil)
        board.setString("conteúdo anterior", forType: .string)

        let injector = InjectorLive(restoreDelayNanoseconds: 50_000_000,
                                    axTrusted: { true },
                                    pasteboard: board)
        _ = try await injector.inject(text: "ditado")

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(board.string(forType: .string), "conteúdo anterior")
    }

    /// Com o clipboard vazio antes, restaurar significaria **apagar** o ditado —
    /// contradizendo o toast que diz que ele está na área de transferência.
    func test_emptyPreviousClipboardLeavesDictationInPlace() async throws {
        let injector = InjectorLive(restoreDelayNanoseconds: 50_000_000,
                                    axTrusted: { true },
                                    pasteboard: board)
        _ = try await injector.inject(text: "ditado")

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(board.string(forType: .string), "ditado",
                       "sem conteúdo anterior, o ditado fica no clipboard")
    }

    func test_injectionError_equatable() {
        XCTAssertEqual(InjectionError.accessibilityDenied, InjectionError.accessibilityDenied)
        XCTAssertNotEqual(InjectionError.accessibilityDenied, InjectionError.pasteboardWriteFailed)
    }
}
