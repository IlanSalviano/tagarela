import Foundation

protocol PermissionService: AnyObject {
    func snapshot() -> PermissionsSnapshot
    func requestMicrophone() async -> Bool
    /// Pede Acessibilidade: o macOS mostra o diálogo dele **e insere o app na
    /// lista** dos Ajustes (sem isso, depois de um `tccutil reset` o usuário
    /// teria de achar o app pelo "+"). Devolve se já está concedida.
    @discardableResult func requestAccessibility() -> Bool
    /// Pede Monitoramento de Entrada. O diálogo só aparece na primeira vez.
    @discardableResult func requestInputMonitoring() -> Bool
    func openAccessibilitySettings()
    func openInputMonitoringSettings()
    func openMicrophoneSettings()

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
