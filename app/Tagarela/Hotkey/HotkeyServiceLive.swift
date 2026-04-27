import AppKit
import OSLog

final class HotkeyServiceLive: HotkeyService, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Hotkey")
    private let hotkey: Hotkey
    private let cancelarComEsc: Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    nonisolated(unsafe) private var continuation: AsyncStream<HotkeyEvent>.Continuation?
    let events: AsyncStream<HotkeyEvent>

    init(hotkey: Hotkey = .default, cancelarComEsc: Bool = true) {
        self.hotkey = hotkey
        self.cancelarComEsc = cancelarComEsc
        var continuationRef: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { continuation in
            continuationRef = continuation
        }
        self.continuation = continuationRef
    }

    func start() throws {
        guard AXIsProcessTrusted() else {
            throw HotkeyServiceError.accessibilityDenied
        }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let observer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: HotkeyServiceLive.callback,
            userInfo: observer
        ) else {
            throw HotkeyServiceError.eventTapCreationFailed
        }
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
        logger.info("HotkeyService started for \(self.hotkey.displayLabel)")
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    // CGEventTap C callback. Não pode capturar contexto Swift; recebe self via refcon.
    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let me = Unmanaged<HotkeyServiceLive>.fromOpaque(refcon).takeUnretainedValue()

        if type == .flagsChanged {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == me.hotkey.virtualKeyCode {
                let flags = event.flags
                // TODO Fase 2: distinguir L/R do Option olhando bits específicos do flag.
                // Por enquanto, qualquer Option (esquerdo OU direito) dispara — refinar
                // se o uso real mostrar incômodo.
                if flags.contains(.maskAlternate) {
                    me.continuation?.yield(.toggle)
                }
            }
        } else if type == .keyDown && me.cancelarComEsc {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 0x35 { // Esc
                me.continuation?.yield(.cancel)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
        continuation?.finish()
    }
}
