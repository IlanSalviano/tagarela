import Foundation

protocol PermissionService: AnyObject {
    func snapshot() -> PermissionsSnapshot
    func requestMicrophone() async -> Bool
    func openAccessibilitySettings()
    func openInputMonitoringSettings()

    /// Stream que reemite snapshot quando algo muda (poll a cada 1s).
    ///
    /// **Um stream por assinante.** Um `AsyncStream` único compartilhado
    /// *divide* os elementos entre consumidores em vez de duplicá-los, e o app
    /// tem dois (`AppContainer` e `OnboardingCoordinator`): o checklist do
    /// onboarding perdia cerca de metade das transições (auditoria §5.2).
    func makeSnapshots() -> AsyncStream<PermissionsSnapshot>

    /// Compat. Prefira `makeSnapshots()`.
    var snapshots: AsyncStream<PermissionsSnapshot> { get }
}

extension PermissionService {
    var snapshots: AsyncStream<PermissionsSnapshot> { makeSnapshots() }
}
