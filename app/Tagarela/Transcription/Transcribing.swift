import Foundation

/// Resultado de uma transcrição, com as métricas que o WhisperKit já produz e
/// que o app jogava fora.
///
/// Existiam para distinguir "o usuário falou baixo" de "o decoder degradou"
/// (hipótese H2 da auditoria de 2026-09-07) — e sem elas o `''` do Whisper era
/// indistinguível de qualquer outra causa.
struct TranscriptionOutcome: Sendable, Equatable {
    var text: String
    var detectedLanguage: String?
    var avgLogprob: Float?
    var compressionRatio: Float?
    var noSpeechProb: Float?
    var wallMs: Int
    var segments: Int

    init(text: String,
         detectedLanguage: String? = nil,
         avgLogprob: Float? = nil,
         compressionRatio: Float? = nil,
         noSpeechProb: Float? = nil,
         wallMs: Int = 0,
         segments: Int = 0) {
        self.text = text
        self.detectedLanguage = detectedLanguage
        self.avgLogprob = avgLogprob
        self.compressionRatio = compressionRatio
        self.noSpeechProb = noSpeechProb
        self.wallMs = wallMs
        self.segments = segments
    }

    /// Linha de log das métricas. Nunca inclui o texto — só o tamanho.
    var metricsLine: String {
        func opt(_ value: Float?) -> String { value.map { String(format: "%.3f", $0) } ?? "?" }
        return "chars=\(text.count) segs=\(segments) wall=\(wallMs)ms "
             + "lang=\(detectedLanguage ?? "?") logprob=\(opt(avgLogprob)) "
             + "cr=\(opt(compressionRatio)) nsp=\(opt(noSpeechProb))"
    }
}

protocol Transcribing: AnyObject, Sendable {
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws
    /// `language == nil` ativa a auto-detecção do Whisper (ver ADR-0006).
    func transcribe(buffer: AudioBuffer,
                    language: String?,
                    initialPrompt: String?) async throws -> TranscriptionOutcome
    func unloadModel()
    /// Descarrega e recarrega o modelo atual **a partir do disco**, sem rede.
    /// É a recuperação disparada por duas transcrições vazias seguidas.
    /// Lança `modelNotLoaded` se não havia modelo carregado.
    func reload() async throws
    var loadedModelName: String? { get }
}

enum TranscribeError: Error, Equatable {
    case modelNotLoaded
    case modelDownloadFailed(String)
    case transcriptionFailed(String)
    case bufferTooShort
}
