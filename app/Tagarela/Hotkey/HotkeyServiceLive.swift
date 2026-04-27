import AppKit
import IOKit.hid
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
        // Listen-only keyboard tap precisa de Input Monitoring; injeção
        // (Injector) precisa de Accessibility. Ambas devem estar concedidas
        // no momento de start().
        // CGEvent.tapCreate listen-only só requer Input Monitoring. Accessibility
        // só é usado pelo Injector pra simular ⌘V — fica checado lá. Se IM não
        // estiver concedido, IOHIDRequestAccess prompta nativamente.
        var imGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if !imGranted {
            FileHandle.standardError.write(Data("[hotkey] requesting Input Monitoring via IOHIDRequestAccess\n".utf8))
            imGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        FileHandle.standardError.write(Data("[hotkey] start() — InputMonitoring granted=\(imGranted)\n".utf8))
        if !imGranted {
            logger.error("Input Monitoring negado mesmo após request")
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
            FileHandle.standardError.write(Data("[hotkey] CGEvent.tapCreate retornou nil\n".utf8))
            logger.error("CGEvent.tapCreate retornou nil — provavelmente falta Input Monitoring no binário atual")
            throw HotkeyServiceError.eventTapCreationFailed
        }
        FileHandle.standardError.write(Data("[hotkey] tap criado, registrando no run loop\n".utf8))
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        // Forçar main run loop (independente de quem chamou start()) — alguns
        // contextos do MainActor não aterrissam exatamente no CFRunLoopGetMain.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
        logger.info("HotkeyService started for \(self.hotkey.displayLabel, privacy: .public)")
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
        logger.info("event tap re-enabled after disable")
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
                FileHandle.standardError.write(Data("[hotkey] flagsChanged keyCode=\(keyCode) (Right Option)\n".utf8))
                let flags = event.flags
                // TODO Fase 2: distinguir L/R do Option olhando bits específicos do flag.
                // Por enquanto, o filtro pelo keyCode (0x3D = Right Option) já restringe
                // ao Option direito; .maskAlternate só serve pra ignorar o evento de
                // release (quando flag é desligado).
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
