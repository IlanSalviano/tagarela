import Foundation

/// Idioma da transcrição do Whisper. `auto` deixa o WhisperKit detectar
/// (language=nil + detectLanguage=true em modelo multilíngue); pt/en fixam
/// o código ISO. Ver ADR-0006.
enum TranscriptionLanguage: String, Codable, CaseIterable, Sendable, Equatable {
    case auto   // default — detecção automática
    case pt
    case en

    var displayName: String {
        switch self {
        case .auto: return String(localized: "transcription.language.auto", defaultValue: "Automático")
        case .pt:   return String(localized: "transcription.language.pt", defaultValue: "Português")
        case .en:   return String(localized: "transcription.language.en", defaultValue: "English")
        }
    }

    /// Código passado ao Whisper. `nil` em `auto` dispara a auto-detecção.
    var whisperCode: String? {
        self == .auto ? nil : rawValue
    }
}
