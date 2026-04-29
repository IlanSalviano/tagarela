import AppKit
import SwiftUI

@MainActor
final class PreferencesWindow {
    private var window: NSWindow?

    func show(content: () -> AnyView) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
