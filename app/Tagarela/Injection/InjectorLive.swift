import AppKit

final class InjectorLive: Injecting, @unchecked Sendable {
    private let restoreDelayNanoseconds: UInt64 = 250_000_000

    func frontmostBundleID() async -> String? {
        await MainActor.run { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    }

    func inject(text: String) async throws -> String? {
        guard AXIsProcessTrusted() else {
            Diag.error(.inject, "AXIsProcessTrusted == false — Acessibilidade caiu")
            throw InjectionError.accessibilityDenied
        }
        let pasteboard = NSPasteboard.general
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // 1. Snapshot do clipboard atual (todos os tipos)
        let savedItems = pasteboard.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        } ?? []

        // 2. Coloca texto novo
        pasteboard.declareTypes([.string], owner: nil)
        guard pasteboard.setString(text, forType: .string) else {
            throw InjectionError.pasteboardWriteFailed
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

        // 4. Restaura clipboard depois do delay
        try? await Task.sleep(nanoseconds: restoreDelayNanoseconds)
        pasteboard.clearContents()
        for dict in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            pasteboard.writeObjects([item])
        }
        Diag.notice(.inject, "clipboard restored (items=\(savedItems.count))")

        return frontBundleID
    }
}
