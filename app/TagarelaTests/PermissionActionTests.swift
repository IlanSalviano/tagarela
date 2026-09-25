import XCTest
@testable import Tagarela

/// O botão de cada permissão em Preferências › Permissões. O relato de campo
/// que motivou isto: "o usuário tem que adivinhar qual precisa". A regra tem
/// que levar sempre a um lugar onde dá para resolver — nunca a um beco.
final class PermissionActionTests: XCTestCase {

    func test_grantedNeedsNoButton() {
        for kind in PermissionKind.allCases {
            XCTAssertEqual(PermissionAction.for(kind, status: .granted), .none, "\(kind)")
        }
    }

    func test_microphoneNeverDecided_asksTheSystem() {
        XCTAssertEqual(PermissionAction.for(.microphone, status: .needed), .request)
        XCTAssertEqual(PermissionAction.for(.microphone, status: .unknown), .request)
    }

    /// Depois de um "não", o macOS não pergunta de novo: pedir seria um botão
    /// que não faz nada. Tem que abrir o painel.
    func test_microphoneDenied_opensSettings() {
        XCTAssertEqual(PermissionAction.for(.microphone, status: .denied), .openSettings)
    }

    /// Monitoramento de Entrada e Acessibilidade: o pedido só mostra diálogo na
    /// primeira vez, mas é o que insere o app na lista dos Ajustes. Então pede
    /// **e** abre o painel — em nenhum estado o clique fica sem efeito.
    func test_inputMonitoringAndAccessibility_requestAndOpenSettings() {
        for kind in [PermissionKind.inputMonitoring, .accessibility] {
            for status in [PermissionStatus.needed, .denied, .unknown] {
                XCTAssertEqual(PermissionAction.for(kind, status: status), .requestAndOpenSettings,
                               "\(kind) \(status)")
            }
        }
    }
}
