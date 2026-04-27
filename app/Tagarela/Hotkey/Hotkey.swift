import Foundation

enum Hotkey: String, Codable, Equatable, Hashable {
    case rightOption

    static let `default`: Hotkey = .rightOption

    /// Virtual keycode usado por CGEventTap. Right Option = 0x3D.
    var virtualKeyCode: UInt16 {
        switch self {
        case .rightOption: return 0x3D
        }
    }

    /// Display string pra UI.
    var displayLabel: String {
        switch self {
        case .rightOption: return "right ⌥"
        }
    }
}
