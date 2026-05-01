import Combine
import Foundation
import OSLog

enum SwapState: Equatable {
    case idle(active: String)
    case downloading(active: String, target: String, progress: Double)
    case swapping(active: String, target: String)
    case failed(active: String, target: String, error: SwapError)
}

enum SwapError: Error, Equatable {
    case downloadFailed(String)
    case loadFailed(String)
    case cancelled
}

/// Orquestra troca de modelo Whisper em runtime.
///
/// Convenção: durante `.downloading` o "transcriber ativo" continua respondendo
/// a hotkey usando o modelo antigo. Coordinator instancia um Transcribing
/// separado (`stagingFactory`) pra baixar/carregar o target. Quando carregamento
/// termina, chama `swapActive` pra trocar o ponteiro no AppContainer; depois
/// chama `unloadModel()` no antigo (passado via callback).
///
/// O coordinator é `@MainActor` — todas as transições de estado e o handoff
/// pro AppContainer rodam serializados na main actor, o que também é a serialização
/// do `unloadModel()` em relação a chamadas de `transcribe()` (que vêm do mesmo
/// caller chain main-actor — ver T4 review).
@MainActor
final class WhisperModelSwapCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.tagarela", category: "SwapCoordinator")

    @Published private(set) var state: SwapState

    /// Factory que cria um novo Transcribing pra staging (download/load do target).
    /// Em produção: `{ WhisperKitTranscriber() }`. Em teste: fake controlado.
    private let stagingFactory: @Sendable () -> Transcribing

    /// Chamado após load do novo terminar com sucesso. Recebe o staging
    /// transcriber (já carregado) e deve trocar o ponteiro ativo no AppContainer
    /// + retornar o transcriber antigo (que será unloaded).
    private let swapActive: @MainActor (_ newActive: Transcribing) -> Transcribing

    private var swapTask: Task<Void, Never>?

    init(initialActive: String,
         stagingFactory: @escaping @Sendable () -> Transcribing,
         swapActive: @escaping @MainActor (_ newActive: Transcribing) -> Transcribing) {
        self.state = .idle(active: initialActive)
        self.stagingFactory = stagingFactory
        self.swapActive = swapActive
    }

    /// Pede troca pro target. Se já está em `.downloading` ou `.swapping`, no-op.
    func requestSwap(target: String) {
        let active: String
        switch state {
        case .idle(let a):
            guard a != target else {
                logger.info("requestSwap ignored (already active=\(a, privacy: .public))")
                return
            }
            active = a
        case .failed(let a, _, _):
            // user picks a different target via picker after seeing error sheet —
            // pivot directly without going through dismissError().
            active = a
        case .downloading, .swapping:
            logger.info("requestSwap ignored (busy state=\(String(describing: self.state), privacy: .public))")
            return
        }
        startSwap(from: active, to: target)
    }

    /// Reinicia swap após `.failed`. Mesma lógica do `requestSwap` mas a partir
    /// do estado de erro.
    func retry() {
        guard case .failed(let active, let target, _) = state else { return }
        startSwap(from: active, to: target)
    }

    /// Cancela download em curso. Volta pra `.idle(active: <original>)`.
    func cancel() {
        swapTask?.cancel()
    }

    /// Sai do estado `.failed` voltando pra `.idle(active: <antigo>)`. Chamado
    /// pelo botão "Fechar" da SwapErrorSheet (ver design doc §175-181). No-op
    /// se state não for `.failed`.
    func dismissError() {
        guard case .failed(let active, _, _) = state else { return }
        state = .idle(active: active)
    }

    private func startSwap(from active: String, to target: String) {
        state = .downloading(active: active, target: target, progress: 0)
        let staging = stagingFactory()
        swapTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await staging.loadModel(target) { [weak self] p in
                    Task { @MainActor in
                        guard let self else { return }
                        if case .downloading(let a, let t, _) = self.state {
                            self.state = .downloading(active: a, target: t, progress: p)
                        }
                    }
                }
                if Task.isCancelled {
                    self.state = .idle(active: active)
                    return
                }
                self.state = .swapping(active: active, target: target)
                let oldActive = self.swapActive(staging)
                oldActive.unloadModel()
                self.state = .idle(active: target)
                self.logger.notice("swap done: \(active, privacy: .public) -> \(target, privacy: .public)")
            } catch is CancellationError {
                self.state = .idle(active: active)
            } catch let TranscribeError.modelDownloadFailed(reason) {
                // Defesa: se cancel() chegou primeiro, Task.isCancelled é true
                // mesmo que o caller tenha rewrap-ado CancellationError em outro
                // tipo de erro. Tratamos como cancelamento. (T5 review C1)
                if Task.isCancelled {
                    self.state = .idle(active: active)
                } else {
                    self.state = .failed(active: active, target: target,
                                         error: .downloadFailed(reason))
                    self.logger.error("swap downloadFailed: \(reason, privacy: .public)")
                }
            } catch {
                if Task.isCancelled {
                    self.state = .idle(active: active)
                } else {
                    self.state = .failed(active: active, target: target,
                                         error: .loadFailed(String(describing: error)))
                    self.logger.error("swap loadFailed: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }
}
