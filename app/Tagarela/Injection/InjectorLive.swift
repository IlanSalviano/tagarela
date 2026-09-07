import AppKit

final class InjectorLive: Injecting, @unchecked Sendable {
    /// 250 ms era curto demais para os alvos reais deste usuário (Claude,
    /// Codex, WhatsApp — todos Electron): eles consomem o ⌘V depois disso, e a
    /// restauração chegava antes, fazendo colar o conteúdo **anterior**.
    private let restoreDelayNanoseconds: UInt64
    private let axTrusted: @Sendable () -> Bool
    private let pasteboard: NSPasteboard

    init(restoreDelayNanoseconds: UInt64 = 400_000_000,
         axTrusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
         pasteboard: NSPasteboard = .general) {
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
        self.axTrusted = axTrusted
        self.pasteboard = pasteboard
    }

    func frontmostBundleID() async -> String? {
        await MainActor.run { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    }

    func inject(text: String) async throws -> String? {
        let frontBundleID = await frontmostBundleID()

        // 1. Snapshot do clipboard atual (todos os tipos)
        let savedItems = pasteboard.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        } ?? []

        // 2. Escreve o texto **antes** de checar a Acessibilidade. Antes era o
        //    contrário: com a Acessibilidade caída o ditado sumia inteiro — não
        //    colava, não ficava no clipboard e não entrava no histórico (S3).
        pasteboard.declareTypes([.string], owner: nil)
        guard pasteboard.setString(text, forType: .string) else {
            throw InjectionError.pasteboardWriteFailed
        }
        let changeCountAfterWrite = pasteboard.changeCount

        guard axTrusted() else {
            Diag.error(.inject, "AXIsProcessTrusted == false — ditado de \(text.count) chars "
                       + "ficou na área de transferência")
            throw InjectionError.accessibilityDenied
        }

        // 3. Simula ⌘V
        let src = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
        Diag.notice(.inject, "pasted to \(frontBundleID ?? "?") chars=\(text.count)")

        // 4. Restauração — ver `scheduleRestore`.
        scheduleRestore(savedItems: savedItems, changeCountAfterWrite: changeCountAfterWrite)
        return frontBundleID
    }

    /// Política de restauração do clipboard (ADR-0008).
    ///
    /// Não há como confirmar que o app-alvo processou o ⌘V, então a regra é
    /// conservadora — na dúvida, **o ditado fica no clipboard**:
    ///
    /// - **Não cancelável.** Roda em `Task.detached`: antes, o Esc do usuário
    ///   cancelava a Task do pipeline, o que interrompia o `sleep` e restaurava
    ///   o clipboard *antes* do app-alvo consumir o ⌘V — colando o conteúdo
    ///   anterior.
    /// - **Só se ninguém mexeu:** `changeCount` tem que ser o mesmo da escrita.
    /// - **Só se havia algo antes.** Com o clipboard anteriormente vazio,
    ///   restaurar significaria apagar o ditado — contradizendo o toast que diz
    ///   que ele está lá.
    private func scheduleRestore(savedItems: [[NSPasteboard.PasteboardType: Data]],
                                 changeCountAfterWrite: Int) {
        guard !savedItems.isEmpty else {
            Diag.notice(.inject, "restore skipped: clipboard anterior estava vazio")
            return
        }
        let delay = restoreDelayNanoseconds
        Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                guard let self else { return }
                guard self.pasteboard.changeCount == changeCountAfterWrite else {
                    Diag.notice(.inject, "restore skipped: clipboard mudou desde a escrita")
                    return
                }
                self.pasteboard.clearContents()
                for dict in savedItems {
                    let item = NSPasteboardItem()
                    for (type, data) in dict { item.setData(data, forType: type) }
                    self.pasteboard.writeObjects([item])
                }
                Diag.notice(.inject, "clipboard restored (items=\(savedItems.count))")
            }
        }
    }
}
