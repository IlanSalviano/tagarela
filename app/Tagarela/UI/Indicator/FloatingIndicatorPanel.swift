import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?

    func show(rootView: some View) {
        if panel == nil {
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
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            self.panel = p
        }
        let host = NSHostingController(rootView: rootView)
        host.view.layer?.backgroundColor = .clear
        panel?.contentViewController = host
        positionNearCursor()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
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
}
