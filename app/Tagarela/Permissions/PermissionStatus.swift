import Foundation

enum PermissionStatus: String, Codable, Equatable {
    case unknown
    case needed
    case granted
    case denied
}

struct PermissionsSnapshot: Equatable, Sendable {
    var microphone: PermissionStatus
    var accessibility: PermissionStatus
    var inputMonitoring: PermissionStatus

    var allGranted: Bool {
        microphone == .granted && accessibility == .granted && inputMonitoring == .granted
    }
}
