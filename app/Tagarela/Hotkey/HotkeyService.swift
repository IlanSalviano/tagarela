import Foundation

enum HotkeyEvent: Equatable {
    case toggle
    case cancel
}

protocol HotkeyService: AnyObject {
    /// Stream de eventos (toggle / cancel) emitidos pela hotkey configurada
    /// e pela tecla Esc (se cancelarComEsc estiver ativo).
    var events: AsyncStream<HotkeyEvent> { get }

    /// Inicia captura. Falha se Acessibilidade ou Input Monitoring não autorizados.
    func start() throws

    func stop()
}

enum HotkeyServiceError: Error, Equatable {
    case accessibilityDenied
    case inputMonitoringDenied
    case eventTapCreationFailed
}
