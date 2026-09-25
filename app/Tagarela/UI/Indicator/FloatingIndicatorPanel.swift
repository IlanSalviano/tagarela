import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?
    /// Task pra preview com auto-hide após N segundos.
    private var previewTask: Task<Void, Never>?

    /// O painel está mostrando o preview do seletor de indicador (centro da
    /// tela), não uma gravação — a posição dele não deve ser herdada.
    private var showingPreview = false

    /// Frame atual — só para os testes observarem deriva.
    var currentFrame: NSRect? { panel?.frame }

    /// Simula o usuário arrastando o painel — só para testes.
    func moveForTesting(to origin: NSPoint) { panel?.setFrameOrigin(origin) }

    /// Mostra (ou atualiza) panel com indicator da `variant` correspondente
    /// + toast opcional empilhado acima.
    func show(state: PipelineState,
              variant: IndicatorVariant,
              toast: Toast?,
              onCancel: @escaping () -> Void,
              onToastDismiss: @escaping () -> Void) {
        ensurePanel()
        // Um preview de 3 s em vôo escondia uma gravação real quando expirava.
        previewTask?.cancel()
        previewTask = nil

        let root = VStack(spacing: 8) {
            if let toast {
                ToastView(kind: toast.kind, onDismiss: onToastDismiss)
            }
            Self.indicator(for: variant, state: state, onCancel: onCancel)
        }
        let host = NSHostingController(rootView: root)
        host.view.layer?.backgroundColor = .clear

        // Trocar o `contentViewController` redimensiona a janela e a desloca
        // para cima (~21 pt por troca, medido em teste). Como isso acontece a
        // cada `.stateChanged` — 12–25 vezes por segundo gravando —, sem
        // compensação a pílula sobe até o topo da tela: foi o bug de campo de
        // 2026-09-24, introduzido quando o 9f parou de reposicionar no cursor
        // a cada tick.
        //
        // A regra agora: a posição que a janela tinha **antes** da troca é
        // restaurada **depois**. Anula a deriva, não persegue o mouse, e não
        // briga com o arrasto — a posição guardada já inclui o que o usuário
        // arrastou.
        let wasVisible = panel?.isVisible == true && !showingPreview
        let origin = panel?.frame.origin
        showingPreview = false
        panel?.contentViewController = host
        if wasVisible, let origin {
            panel?.setFrameOrigin(origin)
        } else {
            positionNearCursor()
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        previewTask?.cancel()
        previewTask = nil
        showingPreview = false
        panel?.orderOut(nil)
    }

    /// Mostra a `variant` em estado fake por `durationSec` segundos. Usado
    /// pelo botão "Visualizar selecionado" no IndicatorPicker (T12). Auto-hide.
    func showPreview(variant: IndicatorVariant,
                     state: PipelineState,
                     durationSec: Double) {
        ensurePanel()
        let root = Self.indicator(for: variant, state: state, onCancel: {})
        let host = NSHostingController(rootView: root)
        host.view.layer?.backgroundColor = .clear
        panel?.contentViewController = host
        positionCenterScreen()
        showingPreview = true
        panel?.orderFrontRegardless()
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSec * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.hide()
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear
        p.hasShadow = false
        // `.fullScreenAuxiliary`: sem ela, ditar num app em tela cheia não
        // mostrava indicador nem toasts (auditoria §5.3).
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.panel = p
    }

    private func positionNearCursor() {
        guard let p = panel else { return }
        let cursor = NSEvent.mouseLocation
        let frame = NSRect(x: cursor.x - 110,
                           y: cursor.y - 80,
                           width: p.frame.width,
                           height: p.frame.height)
        p.setFrame(frame, display: true)
    }

    private func positionCenterScreen() {
        guard let p = panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = NSRect(x: visible.midX - p.frame.width / 2,
                           y: visible.midY - p.frame.height / 2,
                           width: p.frame.width,
                           height: p.frame.height)
        p.setFrame(frame, display: true)
    }

    @ViewBuilder
    static func indicator(for variant: IndicatorVariant,
                          state: PipelineState,
                          onCancel: @escaping () -> Void) -> some View {
        switch variant {
        case .pill:     IndicatorPill(state: state, onCancel: onCancel)
        case .orb:      IndicatorOrb(state: state, onCancel: onCancel)
        case .vertical: IndicatorVertical(state: state, onCancel: onCancel)
        case .hud:      IndicatorHUD(state: state, onCancel: onCancel)
        }
    }
}
