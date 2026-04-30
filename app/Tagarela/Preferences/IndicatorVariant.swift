import Foundation

enum IndicatorVariant: String, Codable, CaseIterable, Sendable, Equatable {
    case pill       // A — default
    case orb        // B
    case vertical   // C
    case hud        // D — dark only

    var displayName: String {
        switch self {
        case .pill:     return String(localized: "indicator.variant.pill", defaultValue: "Pílula")
        case .orb:      return String(localized: "indicator.variant.orb", defaultValue: "Orb")
        case .vertical: return String(localized: "indicator.variant.vertical", defaultValue: "Vertical")
        case .hud:      return String(localized: "indicator.variant.hud", defaultValue: "HUD")
        }
    }

    /// HUD usa dark mode forçado (per ADR-0001). Outros respeitam o tema do sistema.
    var isDarkOnly: Bool {
        self == .hud
    }
}
