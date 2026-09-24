import Foundation

enum PipelineEvent: Equatable, Sendable {
    case toggle
    case cancel
    case stateChanged(PipelineState)
    case finished(rawText: String, refinedText: String, frontmostApp: String?)
    case errorOccurred(String)
    /// Refiner remoto falhou; pipeline cai em IdentityRefiner. Carrega causa
    /// pra surfaceiar em toast. Cleanup #2 da Fase 2a.
    case refinerFellBack(reason: RefinerFallbackReason)
    /// `injector.inject` lançou erro. Texto fica no clipboard mas não foi colado.
    case injectionFailed
    /// `historyStore.save` lançou erro. Captura ocorreu mas não foi persistida.
    case historySaveFailed
    /// `audio.start()` ou inject falhou por falta de permissão.
    case permissionDenied(kind: PermissionKind)
    /// A captura não rendeu áudio utilizável numa gravação que durou o
    /// suficiente. Até a Fase 5 este caminho era **mudo** (S1 da auditoria
    /// §3.4) — o usuário falava, soltava, e nada acontecia.
    case captureFailed(reason: CaptureFailureReason)
    /// Whisper devolveu string vazia. Não injeta e não salva (S2).
    case emptyTranscription
    /// Dois vazios seguidos: o decoder pode ter degradado. Pede ao container
    /// que recrie o transcriber.
    case transcriberRecoveryRequested
    /// Transcriber recriado com sucesso.
    case transcriberRecovered
    /// Hotkey acionada antes de o modelo terminar de carregar. Não é erro do
    /// pipeline — é só cedo demais.
    case transcriberNotReady
}

enum CaptureFailureReason: Equatable, Sendable {
    /// O tap não entregou sample nenhum.
    case noAudio
    /// Veio áudio, mas curto demais para transcrever, numa gravação longa o
    /// bastante para não ser um toque acidental na hotkey.
    case tooShort
}
