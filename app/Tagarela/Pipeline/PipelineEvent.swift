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
}
