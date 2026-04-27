import AppKit
import SwiftUI

/// Modal NSPanel pra cadastrar API key da OpenAI no Keychain.
@MainActor
final class OpenAIKeyPromptWindow {
    private var window: NSPanel?
    private let keychain: KeychainService
    /// Callback chamado se o usuário cancelar (pra reverter prefs.refinerKind quando aplicável).
    var onCancel: (() -> Void)?
    /// Callback chamado se a key foi salva com sucesso.
    var onSaved: (() -> Void)?

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OpenAIKeyPromptView(
            keychain: keychain,
            onCancel: { [weak self] in self?.close(canceled: true) },
            onSaved:  { [weak self] in self?.close(canceled: false) })
        let host = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        panel.title = NSLocalizedString("openai.key.window.title",
                                        value: "API key da OpenAI",
                                        comment: "")
        panel.contentViewController = host
        panel.center()
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        self.window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close(canceled: Bool) {
        window?.close()
        window = nil
        if canceled { onCancel?() } else { onSaved?() }
    }
}

private struct OpenAIKeyPromptView: View {
    let keychain: KeychainService
    let onCancel: () -> Void
    let onSaved: () -> Void
    @State private var keyText: String = ""
    @State private var inlineError: String?

    private static let validKeyPattern = #/^sk-[A-Za-z0-9_\-]{20,}$/#

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("openai.key.body",
                value: "A key fica no Keychain do macOS, no serviço com.tagarela. Nunca aparece em logs nem é enviada para outros lugares.",
                comment: ""))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                // Slot vazio — preserva altura
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
        .frame(width: 360, height: 220)
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
}
