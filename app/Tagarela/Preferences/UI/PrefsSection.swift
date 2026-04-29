import Foundation

enum PrefsSection: String, Hashable, CaseIterable, Identifiable {
    case geral
    case refinerGeral
    case refinerOllama
    case refinerOpenAI
    case estilos
    case audio
    case historico
    case vocabulario
    case atalhos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .geral:         return String(localized: "preferences.section.geral", defaultValue: "Geral")
        case .refinerGeral:  return String(localized: "preferences.section.refiner.geral", defaultValue: "Geral")
        case .refinerOllama: return String(localized: "preferences.section.refiner.ollama", defaultValue: "Ollama")
        case .refinerOpenAI: return String(localized: "preferences.section.refiner.openai", defaultValue: "OpenAI")
        case .estilos:       return String(localized: "preferences.section.estilos", defaultValue: "Estilos")
        case .audio:         return String(localized: "preferences.section.audio", defaultValue: "Áudio")
        case .historico:     return String(localized: "preferences.section.historico", defaultValue: "Histórico")
        case .vocabulario:   return String(localized: "preferences.section.vocabulario", defaultValue: "Vocabulário")
        case .atalhos:       return String(localized: "preferences.section.atalhos", defaultValue: "Atalhos")
        }
    }
}
