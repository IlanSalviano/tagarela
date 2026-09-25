import Foundation

/// O que o botão de uma permissão faz, dado o estado dela.
///
/// Existe porque depois do onboarding não havia lugar nenhum no app para
/// resolver permissões, e os avisos mandavam o usuário "abrir as Preferências",
/// onde não havia nada (relato de campo, 2026-09-25). A regra: todo estado leva
/// a um lugar onde dá para resolver.
enum PermissionAction: Equatable {
    /// Concedida — sem botão.
    case none
    /// Nunca decidida: o sistema mostra o diálogo dele.
    case request
    /// Pede e abre o painel. Para Monitoramento de Entrada e Acessibilidade o
    /// pedido só mostra diálogo na primeira vez, mas é o que coloca o app na
    /// lista dos Ajustes; o painel garante que o clique nunca fique sem efeito.
    case requestAndOpenSettings
    /// Negada: o macOS não pergunta de novo, só o painel resolve.
    case openSettings

    static func `for`(_ kind: PermissionKind, status: PermissionStatus) -> PermissionAction {
        guard status != .granted else { return .none }
        switch kind {
        case .microphone:
            return status == .denied ? .openSettings : .request
        case .inputMonitoring, .accessibility:
            return .requestAndOpenSettings
        }
    }
}
