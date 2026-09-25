import AppKit
import XCTest
@testable import Tagarela

/// O painel aparece na tela durante este teste — o host da suíte é o próprio
/// app, então há um `NSApplication` de verdade rodando.
@MainActor
final class FloatingIndicatorPanelTests: XCTestCase {

    private func tick(_ panel: FloatingIndicatorPanel, _ n: Int) {
        panel.show(state: .recording(elapsedSeconds: Double(n) * 0.08,
                                     audioLevel: Double(n % 5) / 5),
                   variant: .pill, toast: nil,
                   onCancel: {}, onToastDismiss: {})
    }

    /// Campo, 2026-09-24: "a pílula fica subindo até o topo da tela e para por
    /// lá". O 9f parou de reposicionar a cada atualização (para a pílula não
    /// perseguir o mouse), mas cada `show()` ainda troca o
    /// `contentViewController` inteiro, e esse redimensionamento desloca a
    /// janela. Antes, o `setFrame` a cada tick mascarava a deriva; sem ele, ela
    /// se acumula 12–25 vezes por segundo até o topo da tela.
    func test_panelDoesNotDriftAcrossRepeatedUpdates() async throws {
        let panel = FloatingIndicatorPanel()
        defer { panel.hide() }

        tick(panel, 0)
        try await Task.sleep(nanoseconds: 150_000_000)
        let first = try XCTUnwrap(panel.currentFrame)

        for n in 1...30 {
            tick(panel, n)
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let last = try XCTUnwrap(panel.currentFrame)
        XCTAssertEqual(last.origin.y, first.origin.y, accuracy: 1,
                       "o painel se moveu \(last.origin.y - first.origin.y) pt em 30 atualizações")
        XCTAssertEqual(last.origin.x, first.origin.x, accuracy: 1)
    }

    /// Os outros dois requisitos do 9f, que o conserto da deriva não pode
    /// quebrar: arrasto gruda, e o painel só vai ao cursor quando aparece.
    func test_userDragSticks_andPanelReappearsNearCursor() async throws {
        let panel = FloatingIndicatorPanel()
        defer { panel.hide() }

        tick(panel, 0)
        try await Task.sleep(nanoseconds: 100_000_000)
        let placed = try XCTUnwrap(panel.currentFrame)

        // O usuário arrasta o painel para outro canto. Antes do 9f o
        // arrasto era desfeito no tick seguinte (reposicionava no cursor).
        let dragged = NSPoint(x: placed.origin.x - 200, y: placed.origin.y - 150)
        panel.moveForTesting(to: dragged)
        for n in 1...10 {
            tick(panel, n)
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let afterTicks = try XCTUnwrap(panel.currentFrame)
        XCTAssertEqual(afterTicks.origin.x, dragged.x, accuracy: 1,
                       "o arrasto do usuário tem que grudar")
        XCTAssertEqual(afterTicks.origin.y, dragged.y, accuracy: 1,
                       "o arrasto do usuário tem que grudar")

        panel.hide()
        tick(panel, 11)
        let reshown = try XCTUnwrap(panel.currentFrame)
        let cursor = NSEvent.mouseLocation
        XCTAssertEqual(reshown.origin.x, cursor.x - 110, accuracy: 1,
                       "ao reaparecer, volta para perto do cursor")
    }
}
