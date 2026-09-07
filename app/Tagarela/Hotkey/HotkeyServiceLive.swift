import AppKit
import IOKit.hid

final class HotkeyServiceLive: HotkeyService, @unchecked Sendable {
    /// Flag de device do Right Option (`NX_DEVICERALTKEYMASK`). Sem ela o
    /// filtro aceitava `.maskAlternate` agregado: com o Left Option segurado, o
    /// *release* do Right Option ainda trazia `.maskAlternate` ligado e gerava
    /// um segundo `.toggle` — que virava uma gravação de milissegundos,
    /// descartada em silêncio (auditoria §5.2).
    static let rightOptionDeviceMask: UInt64 = 0x40

    private let hotkey: Hotkey
    private let cancelarComEsc: Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var watchdog: Task<Void, Never>?
    private let watchdogIntervalNs: UInt64

    /// Ponto de injeção para teste: conta as reabilitações sem precisar de um
    /// tap real do sistema.
    var onTapReEnabled: (@Sendable () -> Void)?

    nonisolated(unsafe) private var continuation: AsyncStream<HotkeyEvent>.Continuation?
    let events: AsyncStream<HotkeyEvent>

    init(hotkey: Hotkey = .default,
         cancelarComEsc: Bool = true,
         watchdogIntervalNs: UInt64 = 30_000_000_000) {
        self.hotkey = hotkey
        self.cancelarComEsc = cancelarComEsc
        self.watchdogIntervalNs = watchdogIntervalNs
        var continuationRef: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { continuation in
            continuationRef = continuation
        }
        self.continuation = continuationRef
    }

    var isTapEnabled: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() throws {
        // Idempotente: derruba o tap anterior antes de criar outro. Antes,
        // um segundo `start()` sobrescrevia `eventTap` sem invalidar o
        // anterior nem remover a source do run loop.
        teardownTap()

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
        startWatchdog()
        Diag.notice(.hotkey, "started for \(hotkey.displayLabel)")
    }

    func stop() {
        watchdog?.cancel()
        watchdog = nil
        teardownTap()
    }

    private func teardownTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// O callback só reabilita o tap quando o macOS avisa (`tapDisabledBy*`).
    /// Um tap **invalidado** — revogar e reconceder Input Monitoring, por
    /// exemplo — não avisa ninguém: a hotkey simplesmente morre e o usuário só
    /// vê "não faz nada" (S4 da auditoria §3.4). O watchdog cobre esse caso.
    private func startWatchdog() {
        watchdog?.cancel()
        let intervalNs = watchdogIntervalNs
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNs)
                guard let self, let tap = self.eventTap else { return }
                if !self.isTapEnabled {
                    Diag.error(.hotkey, "watchdog: tap desabilitado; reabilitando")
                    CGEvent.tapEnable(tap: tap, enable: true)
                    self.onTapReEnabled?()
                }
            }
        }
    }

    fileprivate func reEnableTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        // `.error`: um tap desabilitado é exatamente S4 da auditoria §3.4 — a
        // hotkey morre em silêncio e o usuário só vê "não faz nada".
        Diag.error(.hotkey, "event tap estava desabilitado; reabilitado")
        onTapReEnabled?()
    }

    // CGEventTap C callback. Não pode capturar contexto Swift; recebe self via refcon.
    // `internal` para que os testes possam chamá-lo com eventos sintéticos.
    static let callback: CGEventTapCallBack = { _, type, event, refcon in
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
                let flags = event.flags
                // keyCode 0x3D (61) é exclusivo do Right Option no macOS.
                // `.maskAlternate` sozinho não distingue press de release quando
                // o Left Option está segurado — a flag de device resolve.
                let deviceHeld = (flags.rawValue & rightOptionDeviceMask) != 0
                Diag.info(.hotkey, "flagsChanged keyCode=\(keyCode) alt=\(flags.contains(.maskAlternate)) rightDevice=\(deviceHeld)")
                if flags.contains(.maskAlternate) && deviceHeld {
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
        watchdog?.cancel()
        teardownTap()
        continuation?.finish()
    }
}
