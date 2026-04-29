import AppKit
import SwiftUI

@MainActor
final class PreferencesWindow {
    private var window: NSWindow?

    func show(content: () -> AnyView) {
        // Dismiss do popover do MenuBarExtra antes de qualquer ordering — sem
        // isso a janela abre por trás do popover quando user clica
        // "Preferências…" no menu da bandeja. Mesmo pattern aplicado em
        // OpenAIKeyPromptWindow.
        Self.dismissMenuBarExtraPopover()
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: content())
        let win = NSWindow(contentViewController: host)
        win.title = String(localized: "preferences.window.title", defaultValue: "Preferências")
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        win.setContentSize(NSSize(width: 720, height: 520))
        win.contentMinSize = NSSize(width: 600, height: 400)
        win.isReleasedWhenClosed = false
        // setFrameAutosaveName por último: lê o frame salvo do UserDefaults e
        // aplica. Se chamado antes de setContentSize, a restoração é
        // sobrescrita e tamanho nunca persiste entre sessões.
        win.setFrameAutosaveName("PreferencesWindow")
        self.window = win
        // activate antes do makeKey: garante que o app está em foreground
        // quando a janela é mostrada (corrige z-order vs popover do MenuBarExtra).
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    /// Fecha o popover do `MenuBarExtra(style: .window)` se estiver visível.
    /// SwiftUI não expõe API pra isso — identificamos a janela pelo nome da classe interna.
    /// Mesmo helper usado em `OpenAIKeyPromptWindow`.
    private static func dismissMenuBarExtraPopover() {
        for window in NSApp.windows where window.isVisible {
            let typeName = String(describing: type(of: window))
            if typeName.contains("MenuBarExtra") || typeName.contains("NSStatusBarWindow") {
                window.orderOut(nil)
            }
        }
    }
}
