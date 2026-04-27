import Foundation

protocol PermissionService: AnyObject {
    func snapshot() -> PermissionsSnapshot
    func requestMicrophone() async -> Bool
    func openAccessibilitySettings()
    func openInputMonitoringSettings()

    /// Stream que reemite snapshot quando algo muda (poll a cada 1s).
    var snapshots: AsyncStream<PermissionsSnapshot> { get }
}
