import AppKit
import IOKit.hid

final class HotkeyServiceLive: HotkeyService, @unchecked Sendable {
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
        // Listen-only keyboard tap precisa de Input Monitoring; injeção
        // (Injector) precisa de Accessibility. Ambas devem estar concedidas
        // no momento de start().
        // CGEvent.tapCreate listen-only só requer Input Monitoring. Accessibility
        // só é usado pelo Injector pra simular ⌘V — fica checado lá. Se IM não
        // estiver concedido, IOHIDRequestAccess prompta nativamente.
        var imGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if !imGranted {
            Diag.info(.hotkey, "requesting Input Monitoring via IOHIDRequestAccess")
            imGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        Diag.info(.hotkey, "start() — InputMonitoring granted=\(imGranted)")
        if !imGranted {
            Diag.error(.hotkey, "Input Monitoring negado mesmo após request")
            throw HotkeyServiceError.inputMonitoringDenied
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
            Diag.error(.hotkey, "CGEvent.tapCreate retornou nil — provavelmente falta Input Monitoring no binário atual")
            throw HotkeyServiceError.eventTapCreationFailed
        }
        Diag.info(.hotkey, "tap criado, registrando no run loop")
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        // Forçar main run loop (independente de quem chamou start()) — alguns
        // contextos do MainActor não aterrissam exatamente no CFRunLoopGetMain.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
        Diag.notice(.hotkey, "started for \(hotkey.displayLabel)")
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func reEnableTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        // `.error`: um tap desabilitado é exatamente S4 da auditoria §3.4 — a
        // hotkey morre em silêncio e o usuário só vê "não faz nada".
        Diag.error(.hotkey, "event tap estava desabilitado; reabilitado")
    }

    // CGEventTap C callback. Não pode capturar contexto Swift; recebe self via refcon.
    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let me = Unmanaged<HotkeyServiceLive>.fromOpaque(refcon).takeUnretainedValue()

        // macOS desabilita o tap se ele bloquear o run loop por muito tempo
        // ou via input do user — precisamos reabilitar.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            me.reEnableTap()
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == me.hotkey.virtualKeyCode {
                Diag.info(.hotkey, "flagsChanged keyCode=\(keyCode) (Right Option)")
                let flags = event.flags
                // keyCode 0x3D (61) é exclusivo do Right Option no macOS — validado
                // empiricamente em 2026-05-01. Left Option dispara keyCode diferente,
                // que cai fora deste bloco. .maskAlternate ignora release events.
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
