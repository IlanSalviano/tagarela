import AppKit
import SwiftUI

/// Modal NSPanel pra cadastrar API key da OpenAI no Keychain.
@MainActor
final class OpenAIKeyPromptWindow {
    private var window: NSPanel?
    private var closeObserver: NSObjectProtocol?
    private let keychain: KeychainService
    /// Callback chamado se o usuário cancelar (pra reverter prefs.refinerKind quando aplicável).
    var onCancel: (() -> Void)?
    /// Callback chamado se a key foi salva com sucesso.
    var onSaved: (() -> Void)?

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    /// Callbacks explícitos por chamada. Antes, o caminho via Preferências não
    /// resetava `onCancel`/`onSaved`, e as closures do último fluxo do menu
    /// continuavam armadas: cancelar em "Alterar…" revertia `refinerKind` para
    /// um `previous` antigo (auditoria §5.3).
    func show(onCancel: (() -> Void)? = nil, onSaved: (() -> Void)? = nil) {
        self.onCancel = onCancel
        self.onSaved = onSaved
        show()
    }

    func show() {
        Self.dismissMenuBarExtraPopover()
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let view = OpenAIKeyPromptView(
            keychain: keychain,
            onCancel: { [weak self] in self?.close(canceled: true) },
            onSaved:  { [weak self] in self?.close(canceled: false) })
        let host = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        panel.title = NSLocalizedString("openai.key.window.title",
                                        value: "API key da OpenAI",
                                        comment: "")
        panel.contentViewController = host
        panel.center()
        // Acima do popover do MenuBarExtra (que vive em .popUpMenu = 101).
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        panel.hidesOnDeactivate = false
        self.window = panel
        // Fechar no ⨯ nunca chamava `close(canceled:)`: o rollback de
        // `refinerKind` não disparava e o backend ficava em OpenAI sem key,
        // fazendo todo ditado cair em "API key inválida" (auditoria §5.3).
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleUserClose() }
            }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Fechamento vindo do próprio sistema de janelas (⨯ ou ⌘W).
    private func handleUserClose() {
        guard window != nil else { return }   // já tratado por close(canceled:)
        removeCloseObserver()
        window = nil
        onCancel?()
    }

    private func removeCloseObserver() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
    }

    /// Fecha o popover do `MenuBarExtra(style: .window)` se estiver visível.
    /// SwiftUI não expõe API pra isso — identificamos a janela pelo nome da classe interna.
    private static func dismissMenuBarExtraPopover() {
        for window in NSApp.windows where window.isVisible {
            let typeName = String(describing: type(of: window))
            if typeName.contains("MenuBarExtra") || typeName.contains("NSStatusBarWindow") {
                window.orderOut(nil)
            }
        }
    }

    private func close(canceled: Bool) {
        // Solta o observer antes do `close()` pra não disparar o caminho de
        // fechamento pelo usuário em cima deste.
        removeCloseObserver()
        let panel = window
        window = nil
        panel?.close()
        if canceled { onCancel?() } else { onSaved?() }
    }
}

private struct OpenAIKeyPromptView: View {
    let keychain: KeychainService
    let onCancel: () -> Void
    let onSaved: () -> Void
    @State private var keyText: String = ""
    @State private var inlineError: String?
    @State private var existingKeyHint: String?

    private static let validKeyPattern = #/^sk-[A-Za-z0-9_\-]{20,}$/#

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("openai.key.body",
                value: "A key fica no Keychain do macOS, no serviço com.tagarela. Nunca aparece em logs nem é enviada para outros lugares.",
                comment: ""))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let existingKeyHint {
                (Text(NSLocalizedString("openai.key.existing.prefix",
                    value: "Key cadastrada: ", comment: ""))
                + Text(existingKeyHint).bold()
                + Text(NSLocalizedString("openai.key.existing.suffix",
                    value: ". Digite uma nova pra substituir.", comment: "")))
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            SecureField("sk-…", text: $keyText)
                .textFieldStyle(.roundedBorder)
            if let inlineError {
                Label(inlineError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if !keyText.isEmpty && keyText.firstMatch(of: Self.validKeyPattern) == nil {
                Label(NSLocalizedString("openai.key.warning.format",
                    value: "Formato parece inválido — você ainda pode salvar mesmo assim.",
                    comment: ""),
                    systemImage: "info.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } else {
                Text(" ").font(.caption)
            }
            HStack {
                Spacer()
                Button(NSLocalizedString("common.cancel", value: "Cancelar", comment: ""), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(NSLocalizedString("common.save", value: "Salvar", comment: "")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(keyText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360, height: 240)
        .onAppear {
            if let key = (try? keychain.openAIKey()) ?? nil, !key.isEmpty {
                existingKeyHint = Self.mask(key)
            } else {
                existingKeyHint = nil
            }
        }
    }

    private func save() {
        do {
            try keychain.setOpenAIKey(keyText)
            onSaved()
        } catch {
            inlineError = NSLocalizedString("openai.key.error.save",
                value: "Não foi possível salvar — tente de novo.", comment: "")
        }
    }

    private static func mask(_ key: String) -> String {
        let suffixCount = min(4, key.count)
        return "sk-…\(String(key.suffix(suffixCount)))"
    }
}
