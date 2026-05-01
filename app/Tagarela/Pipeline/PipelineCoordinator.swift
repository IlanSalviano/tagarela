import Foundation
import OSLog

actor PipelineCoordinator {
    private let logger = Logger(subsystem: "com.tagarela", category: "Pipeline")
    private let audio: AudioCapturing
    private let transcriber: Transcribing
    private let refinerProvider: @MainActor @Sendable () -> (refiner: TextRefiner, style: Style)
    private let injector: Injecting
    private let historyStore: HistoryStore
    private let historyMaxItemsProvider: @MainActor @Sendable () -> Int
    private let historyMaxDaysProvider: @MainActor @Sendable () -> Int
    private let llmModelNameProvider: @MainActor @Sendable (RefinerKind) -> String?
    private let whisperModelNameProvider: @Sendable () -> String
    private let language: String
    private let initialPromptProvider: @MainActor @Sendable () -> String?

    private(set) var state: PipelineState = .idle
    private var continuation: AsyncStream<PipelineEvent>.Continuation?
    nonisolated let events: AsyncStream<PipelineEvent>

    private var startTime: Date?
    private var currentLevel: Double = 0
    private var recordingTasks: [Task<Void, Never>] = []
    /// Sinaliza que o usuário cancelou durante .processing/.refining.
    /// `runTranscribeAndInject` checa após cada await pra abortar antes de inject/save.
    private var cancelled = false
    /// Task que envolve `runTranscribeAndInject` durante .processing/.refining.
    /// `handleCancel` chama `cancel()` aqui pra abortar URLSession em vôo
    /// (URLSession honra Task cancellation nativamente). Lazy: só populada
    /// na transição .recording → .processing.
    /// `internal private(set)` pra permitir verificação em tests via @testable.
    internal private(set) var pipelineTask: Task<Void, Never>?

    init(audio: AudioCapturing,
         transcriber: Transcribing,
         refinerProvider: @escaping @MainActor @Sendable () -> (refiner: TextRefiner, style: Style),
         injector: Injecting,
         historyStore: HistoryStore,
         historyMaxItemsProvider: @escaping @MainActor @Sendable () -> Int,
         historyMaxDaysProvider: @escaping @MainActor @Sendable () -> Int,
         llmModelNameProvider: @escaping @MainActor @Sendable (RefinerKind) -> String?,
         whisperModelNameProvider: @escaping @Sendable () -> String,
         language: String = "pt",
         initialPromptProvider: @escaping @MainActor @Sendable () -> String? = { nil }) {
        self.audio = audio
        self.transcriber = transcriber
        self.refinerProvider = refinerProvider
        self.injector = injector
        self.historyStore = historyStore
        self.historyMaxItemsProvider = historyMaxItemsProvider
        self.historyMaxDaysProvider = historyMaxDaysProvider
        self.llmModelNameProvider = llmModelNameProvider
        self.whisperModelNameProvider = whisperModelNameProvider
        self.language = language
        self.initialPromptProvider = initialPromptProvider

        var ref: AsyncStream<PipelineEvent>.Continuation!
        self.events = AsyncStream { c in ref = c }
        self.continuation = ref
    }

    func handle(_ event: PipelineEvent) async {
        switch event {
        case .toggle: await handleToggle()
        case .cancel: await handleCancel()
        default: break
        }
    }

    private func setState(_ s: PipelineState) {
        state = s
        continuation?.yield(.stateChanged(s))
    }

    private func handleToggle() async {
        logger.info("toggle in state=\(String(describing: self.state), privacy: .public)")
        // Recovery: se estamos em .error, o toggle limpa o estado e tenta de novo.
        if case .error = state {
            setState(.idle)
        }
        switch state {
        case .idle:
            do {
                try audio.start()
                startTime = Date()
                currentLevel = 0
                setState(.recording(elapsedSeconds: 0, audioLevel: 0))
                spawnRecordingTasks()
            } catch AudioCaptureError.microphoneDenied {
                continuation?.yield(.permissionDenied(kind: .microphone))
                setState(.error(message: "mic"))
                continuation?.yield(.errorOccurred("mic denied"))
            } catch {
                setState(.error(message: "mic indisponível"))
                continuation?.yield(.errorOccurred("mic: \(error)"))
            }
        case .recording:
            cancelRecordingTasks()
            pipelineTask = Task { [weak self] in
                await self?.runTranscribeAndInject()
                await self?.clearPipelineTask()
            }
        case .processing, .refining, .error:
            // Ignorado — apenas .cancel é aceito durante esses estados
            break
        }
    }

    private func handleCancel() async {
        logger.info("cancel received in state=\(String(describing: self.state), privacy: .public)")
        switch state {
        case .recording:
            cancelRecordingTasks()
            _ = try? await audio.stop()
            setState(.idle)
        case .processing, .refining:
            // Sinaliza cancel pra runTranscribeAndInject (via flag — checkpoints
            // pós-await) E propaga Task.cancel() pra abortar URLSession em vôo.
            // URLSession honra cancellation nativamente; WhisperKit é best-effort.
            // A flag `cancelled` é setada ANTES do cancel() pra que, quando
            // RefinerError.cancelled chegar no catch do refine, o `where cancelled`
            // case (PipelineCoordinator.swift:184-205) distinga user-cancel real
            // de network-drop disfarçado (commit 99d174e).
            cancelled = true
            pipelineTask?.cancel()
            setState(.idle)
        case .idle, .error:
            break
        }
    }

    private func spawnRecordingTasks() {
        let levels = audio.levels
        recordingTasks.append(Task { [weak self] in
            for await lv in levels {
                await self?.setLevel(lv)
            }
        })
        recordingTasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                await self?.tickElapsed()
            }
        })
    }

    private func cancelRecordingTasks() {
        for t in recordingTasks { t.cancel() }
        recordingTasks.removeAll()
    }

    private func setLevel(_ v: Double) {
        currentLevel = v
        if case .recording(let elapsed, _) = state {
            setState(.recording(elapsedSeconds: elapsed, audioLevel: v))
        }
    }

    private func tickElapsed() {
        guard case .recording = state, let st = startTime else { return }
        let elapsed = Date().timeIntervalSince(st)
        setState(.recording(elapsedSeconds: elapsed, audioLevel: currentLevel))
    }

    /// Agrega user-cancel via flag (Esc durante .processing/.refining) e
    /// cancellation cooperativa da Task (Task.cancel() propagado externamente).
    /// Substitui as checagens isoladas de `if cancelled` nos checkpoints
    /// internos do `runTranscribeAndInject`.
    private func aborted() -> Bool {
        cancelled || Task.isCancelled
    }

    private func clearPipelineTask() {
        pipelineTask = nil
    }

    private func runTranscribeAndInject() async {
        cancelled = false
        do {
            logger.info("stopping audio")
            let buffer = try await audio.stop()
            logger.info("buffer duration=\(buffer.durationSeconds, privacy: .public)s samples=\(buffer.samples.count, privacy: .public)")
            guard buffer.durationSeconds >= 0.5 else {
                logger.info("buffer too short, descartando")
                setState(.idle); return
            }
            setState(.processing)
            logger.info("transcribing (model loaded? \(self.transcriber.loadedModelName ?? "NIL", privacy: .public))")
            let raw = try await transcriber.transcribe(
                buffer: buffer,
                language: language,
                initialPrompt: await initialPromptProvider()
            )
            if aborted() { logger.info("cancelled after transcribe"); setState(.idle); return }
            logger.info("transcribed: '\(raw, privacy: .public)'")
            let (refiner, style) = await refinerProvider()
            let actualRefinerKind: RefinerKind
            let refined: String

            if refiner.kind == .none {
                // Identity (cru style ou refinerKind=.none): skip .refining, pass-through instantâneo.
                // Coerente com spec §3 ("style cru pula .refining").
                refined = (try? await refiner.refine(raw, style: style)) ?? raw
                actualRefinerKind = .none
            } else {
                setState(.refining)
                do {
                    refined = try await refiner.refine(raw, style: style)
                    actualRefinerKind = refiner.kind
                } catch RefinerError.cancelled where cancelled {
                    // Cancelamento real do usuário (flag `cancelled` foi setada
                    // por handleCancel via Esc). Aborta sem fallback nem inject.
                    logger.info("refiner cancelled (user)")
                    setState(.idle); return
                } catch {
                    logger.error("refiner failed (\(refiner.kind.rawValue, privacy: .public)): \(String(describing: error), privacy: .public)")
                    // Cleanup #2 da Fase 2a: surfaceiar fallback ao usuário via toast.
                    // Se vier RefinerError.cancelled SEM a flag `cancelled` ligada,
                    // é network-drop disfarçado (URLSession -999 quando remote
                    // termina conexão abruptamente, ex: `pkill ollama`). Trata
                    // como networkOffline.
                    let reason: RefinerFallbackReason?
                    if let refinerError = error as? RefinerError {
                        if case .cancelled = refinerError {
                            reason = .networkOffline   // network-drop disguised
                        } else {
                            reason = RefinerFallbackReason(refinerError: refinerError)
                        }
                    } else {
                        reason = nil
                    }
                    if let reason {
                        continuation?.yield(.refinerFellBack(reason: reason))
                    }
                    let identityFallback = IdentityRefiner()
                    refined = (try? await identityFallback.refine(raw, style: style)) ?? raw
                    actualRefinerKind = identityFallback.kind
                }
            }
            if aborted() { logger.info("cancelled after refine"); setState(.idle); return }
            logger.info("injecting (kind=\(actualRefinerKind.rawValue, privacy: .public))")
            let frontApp: String?
            do {
                frontApp = try await injector.inject(text: refined)
            } catch InjectionError.accessibilityDenied {
                continuation?.yield(.permissionDenied(kind: .accessibility))
                setState(.idle)
                return
            } catch {
                logger.error("inject failed: \(String(describing: error), privacy: .public)")
                continuation?.yield(.injectionFailed)
                setState(.idle)
                return
            }
            if aborted() { logger.info("cancelled after inject"); setState(.idle); return }
            logger.info("injected to \(frontApp ?? "?", privacy: .public)")
            do {
                let maxItems = await historyMaxItemsProvider()
                let maxDays = await historyMaxDaysProvider()
                let llmModel = await llmModelNameProvider(actualRefinerKind)
                try await historyStore.save(
                    TranscriptionInput(
                        durationSeconds: buffer.durationSeconds,
                        rawText: raw,
                        refinedText: refined,
                        refinerKind: actualRefinerKind.rawValue,
                        llmModelName: llmModel,
                        whisperModelName: whisperModelNameProvider(),
                        styleName: style.name,
                        frontmostAppBundleID: frontApp),
                    maxItems: maxItems,
                    maxDays:  maxDays)
            } catch {
                logger.error("history save failed: \(String(describing: error), privacy: .public)")
                continuation?.yield(.historySaveFailed)
            }
            continuation?.yield(.finished(rawText: raw,
                                          refinedText: refined,
                                          frontmostApp: frontApp))
            setState(.idle)
        } catch {
            logger.error("FALHOU: \(String(describing: error), privacy: .public)")
            setState(.error(message: "erro no pipeline"))
            continuation?.yield(.errorOccurred(String(describing: error)))
            // Auto-recover pra idle após 2s
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            setState(.idle)
        }
    }

    deinit { continuation?.finish() }
}
