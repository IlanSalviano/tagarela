import AppKit
import XCTest
@testable import Tagarela

/// Usam um `NSPasteboard` nomeado próprio, não o `general` — assim não mexem no
/// clipboard de quem estiver rodando a suíte.
final class InjectorTests: XCTestCase {
    private var board: NSPasteboard!
    /// Stands in for the real ⌘V, which would go to whatever app the user has
    /// in front while the suite runs.
    private var paste: PasteRecorder!

    override func setUp() {
        super.setUp()
        board = NSPasteboard(name: .init("com.tagarela.tests.\(UUID().uuidString)"))
        board.clearContents()
        paste = PasteRecorder()
    }

    override func tearDown() {
        board.releaseGlobally()
        board = nil
        paste = nil
        super.tearDown()
    }

    private func makeInjector(axTrusted: Bool,
                              restoreDelayNanoseconds: UInt64 = 50_000_000) -> InjectorLive {
        let paste = self.paste!
        return InjectorLive(restoreDelayNanoseconds: restoreDelayNanoseconds,
                            axTrusted: { axTrusted },
                            pasteboard: board,
                            postPaste: { paste.record() })
    }

    /// S3 da auditoria: `AXIsProcessTrusted()` era checado **antes** da escrita,
    /// então com a Acessibilidade caída o ditado sumia inteiro — não colava, não
    /// ficava no clipboard e (com a ordem antiga) nem entrava no histórico.
    func test_textReachesPasteboardEvenWhenAccessibilityDenied() async {
        let injector = makeInjector(axTrusted: false)

        do {
            _ = try await injector.inject(text: "ditado importante")
            XCTFail("deveria lançar accessibilityDenied")
        } catch {
            XCTAssertEqual(error as? InjectionError, .accessibilityDenied)
        }

        XCTAssertEqual(board.string(forType: .string), "ditado importante",
                       "o ditado tem que sobrar na área de transferência")
        XCTAssertEqual(paste.count, 0, "sem Acessibilidade, nenhum ⌘V sai")
    }

    func test_pasteIsSentExactlyOnceWhenAccessibilityGranted() async throws {
        let injector = makeInjector(axTrusted: true)

        _ = try await injector.inject(text: "ditado")

        XCTAssertEqual(paste.count, 1, "com Acessibilidade, o ⌘V sai uma vez")
    }

    func test_restoreSkippedWhenClipboardChanged() async throws {
        board.declareTypes([.string], owner: nil)
        board.setString("conteúdo anterior", forType: .string)

        let injector = makeInjector(axTrusted: true)
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

        let injector = makeInjector(axTrusted: true)
        _ = try await injector.inject(text: "ditado")

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(board.string(forType: .string), "conteúdo anterior")
    }

    /// Com o clipboard vazio antes, restaurar significaria **apagar** o ditado —
    /// contradizendo o toast que diz que ele está na área de transferência.
    func test_emptyPreviousClipboardLeavesDictationInPlace() async throws {
        let injector = makeInjector(axTrusted: true)
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

/// Counts ⌘V sends; `inject` may call it off the main thread.
private final class PasteRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var sent = 0

    var count: Int { lock.withLock { sent } }

    func record() { lock.withLock { sent += 1 } }
}
