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

    /// `true` quando o tap existe e está habilitado. Alimenta o snapshot da
    /// exportação de diagnóstico e o watchdog.
    var isTapEnabled: Bool { get }
}

extension HotkeyService {
    var isTapEnabled: Bool { false }
}

enum HotkeyServiceError: Error, Equatable {
    case accessibilityDenied
    case inputMonitoringDenied
    case eventTapCreationFailed
}
