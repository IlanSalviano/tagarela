import Foundation

enum PermissionKind: String, Codable, CaseIterable, Sendable, Equatable {
    case microphone
    case accessibility
    case inputMonitoring
}
