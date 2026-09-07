import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?
    /// Task pra preview com auto-hide após N segundos.
    private var previewTask: Task<Void, Never>?

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
        panel?.contentViewController = host
        // Reposicionar só na transição oculto → visível: `.stateChanged` chega
        // 12–25×/s gravando, e reposicionar a cada tick fazia o indicador
        // **seguir o mouse** e desfazia qualquer arrasto do usuário.
        if panel?.isVisible != true { positionNearCursor() }
        panel?.orderFrontRegardless()
    }

    func hide() {
        previewTask?.cancel()
        previewTask = nil
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
