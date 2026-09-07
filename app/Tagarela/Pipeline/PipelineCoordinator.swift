import Foundation

private func fmt(_ value: Double, _ places: Int = 2) -> String {
    String(format: "%.\(places)f", value)
}

actor PipelineCoordinator {
    private let audio: AudioCapturing
    private let transcriberProvider: @MainActor @Sendable () -> Transcribing
    private let refinerProvider: @MainActor @Sendable () -> (refiner: TextRefiner, style: Style)
    private let injector: Injecting
    private let historyStore: HistoryStore
    private let historyMaxItemsProvider: @MainActor @Sendable () -> Int
    private let historyMaxDaysProvider: @MainActor @Sendable () -> Int
    private let llmModelNameProvider: @MainActor @Sendable (RefinerKind) -> String?
    private let whisperModelNameProvider: @MainActor @Sendable () -> String
    /// `nil` → auto-detecção do idioma (ver ADR-0006). Closure pra ler a pref
    /// em runtime, igual aos demais providers — idioma é stateless, não precisa
    /// de swap como o modelo Whisper.
    private let languageProvider: @MainActor @Sendable () -> String?
    private let initialPromptProvider: @MainActor @Sendable () -> String?
    /// Injetável para que os testes atravessem o limiar de wall-clock sem
    /// dormir segundos de verdade.
    private let now: @Sendable () -> Date

    private(set) var state: PipelineState = .idle
    private var continuation: AsyncStream<PipelineEvent>.Continuation?
    nonisolated let events: AsyncStream<PipelineEvent>

    private var startTime: Date?
    private var currentLevel: Double = 0
    /// Consome os níveis da gravação corrente. **Nunca** é cancelada: cancelar
    /// o consumidor termina o `AsyncStream`, e era isso que deixava os
    /// indicadores em `audioLevel = 0` da segunda gravação em diante
    /// (auditoria §5.1). Ela acaba sozinha quando o `stop()` finaliza o stream.
    private var levelsTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    /// Sinaliza que o usuário cancelou durante .processing/.refining.
    /// `runTranscribeAndInject` checa após cada await pra abortar antes de inject/save.
    private var cancelled = false
    /// Transcrições vazias em sequência. Duas seguidas pedem a recriação do
    /// transcriber: é a única forma de distinguir "decoder degradou" de
    /// "o usuário não falou" sem métrica do WhisperKit (hipótese H2).
    private var consecutiveEmpty = 0
    /// Task que envolve `runTranscribeAndInject` durante .processing/.refining.
    /// `handleCancel` chama `cancel()` aqui pra abortar URLSession em vôo
    /// (URLSession honra Task cancellation nativamente). Lazy: só populada
    /// na transição .recording → .processing.
    /// `internal private(set)` pra permitir verificação em tests via @testable.
    internal private(set) var pipelineTask: Task<Void, Never>?

    init(audio: AudioCapturing,
         transcriberProvider: @escaping @MainActor @Sendable () -> Transcribing,
         refinerProvider: @escaping @MainActor @Sendable () -> (refiner: TextRefiner, style: Style),
         injector: Injecting,
         historyStore: HistoryStore,
         historyMaxItemsProvider: @escaping @MainActor @Sendable () -> Int,
         historyMaxDaysProvider: @escaping @MainActor @Sendable () -> Int,
         llmModelNameProvider: @escaping @MainActor @Sendable (RefinerKind) -> String?,
         whisperModelNameProvider: @escaping @MainActor @Sendable () -> String,
         languageProvider: @escaping @MainActor @Sendable () -> String? = { nil },
         initialPromptProvider: @escaping @MainActor @Sendable () -> String? = { nil },
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.audio = audio
        self.transcriberProvider = transcriberProvider
        self.refinerProvider = refinerProvider
        self.injector = injector
        self.historyStore = historyStore
        self.historyMaxItemsProvider = historyMaxItemsProvider
        self.historyMaxDaysProvider = historyMaxDaysProvider
        self.llmModelNameProvider = llmModelNameProvider
        self.whisperModelNameProvider = whisperModelNameProvider
        self.languageProvider = languageProvider
        self.initialPromptProvider = initialPromptProvider
        self.now = now

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

    /// Chamado pelo `AppContainer` quando a recriação do transcriber termina.
    /// Mantém toast e contadores num caminho só — o de eventos.
    func noteTranscriberRecovered() {
        continuation?.yield(.transcriberRecovered)
    }

    private func setState(_ s: PipelineState) {
        state = s
        continuation?.yield(.stateChanged(s))
    }

    private func handleToggle() async {
        Diag.notice(.pipeline, "toggle in state=\(String(describing: state))")
        // Recovery: se estamos em .error, o toggle limpa o estado e tenta de novo.
        if case .error = state {
            setState(.idle)
        }
        switch state {
        case .idle:
            // WhisperKit só checa cancelamento entre etapas, então um Esc
            // durante "transcrevendo" deixa um transcribe() em vôo. Começar
            // outro na mesma instância mistura resultados (auditoria §5.1).
            await awaitPreviousPipeline()
            do {
                try audio.start()
                startTime = now()
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
        Diag.notice(.pipeline, "cancel in state=\(String(describing: state))")
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
        // Lido DEPOIS de `audio.start()`: o stream é por gravação.
        let levels = audio.levels
        levelsTask = Task { [weak self] in
            for await level in levels {
                await self?.setLevel(level)
            }
        }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                await self?.tickElapsed()
            }
        }
    }

    /// Só o ticker é cancelado — ver comentário em `levelsTask`.
    private func cancelRecordingTasks() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func setLevel(_ v: Double) {
        currentLevel = v
        if case .recording(let elapsed, _) = state {
            setState(.recording(elapsedSeconds: elapsed, audioLevel: v))
        }
    }

    private func tickElapsed() {
        guard case .recording = state, let st = startTime else { return }
        let elapsed = now().timeIntervalSince(st)
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

    /// Espera a pipeline anterior terminar, com teto. O polling deixa o actor
    /// livre entre as checagens, o que é o que permite ao `clearPipelineTask`
    /// rodar.
    private func awaitPreviousPipeline(timeoutMs: Int = 3_000) async {
        guard pipelineTask != nil else { return }
        var waited = 0
        while pipelineTask != nil && waited < timeoutMs {
            try? await Task.sleep(nanoseconds: 20_000_000)
            waited += 20
        }
        if pipelineTask != nil {
            Diag.error(.pipeline, "pipeline anterior não terminou em \(timeoutMs)ms — seguindo assim mesmo")
        }
    }

    private func runTranscribeAndInject() async {
        cancelled = false
        do {
            Diag.info(.pipeline, "stopping audio")
            let buffer: AudioBuffer
            do {
                buffer = try await audio.stop()
            } catch AudioCaptureError.noAudioDelivered {
                Diag.error(.pipeline, "captura não entregou áudio — gravação perdida")
                continuation?.yield(.captureFailed(reason: .noAudio))
                setState(.idle)
                return
            }
            let wall = startTime.map { now().timeIntervalSince($0) } ?? 0
            Diag.notice(.pipeline, "buffer duration=\(fmt(buffer.durationSeconds))s samples=\(buffer.samples.count) wall=\(fmt(wall))s")
            guard buffer.durationSeconds >= 0.5 else {
                // O wall-clock separa um toque acidental na hotkey (silencioso,
                // esperado) de uma gravação de verdade que não rendeu áudio —
                // que é S1 da auditoria §3.4, o caminho mudo mais compatível
                // com a queixa "não fez o STT".
                if wall >= 1.0 {
                    Diag.error(.pipeline, "buffer too short: \(fmt(buffer.durationSeconds))s de áudio para \(fmt(wall))s de gravação — descartando")
                    continuation?.yield(.captureFailed(reason: .tooShort))
                } else {
                    Diag.notice(.pipeline, "buffer too short (\(fmt(buffer.durationSeconds))s, wall=\(fmt(wall))s) — descartando")
                }
                setState(.idle); return
            }
            setState(.processing)
            let transcriber = await transcriberProvider()
            Diag.info(.pipeline, "transcribing (model loaded? \(transcriber.loadedModelName ?? "NIL"))")
            let outcome = try await transcriber.transcribe(
                buffer: buffer,
                language: await languageProvider(),
                initialPrompt: await initialPromptProvider()
            )
            let raw = outcome.text
            if aborted() { Diag.notice(.pipeline, "cancelled after transcribe"); setState(.idle); return }
            // NUNCA logar o texto: só o tamanho. Vazio é o caminho S2 da
            // auditoria §3.4 — indistinguível de sucesso sem esta linha.
            if raw.isEmpty {
                consecutiveEmpty += 1
                // O pico pós-boost separa "não falei" de "o decoder devolveu
                // nada apesar de haver sinal" — a diferença que a auditoria
                // não conseguiu fazer (hipóteses H1 × H2).
                let peak = audio.lastStats.map { String(format: "%.3f", $0.peakAfter) } ?? "?"
                Diag.error(.pipeline, "transcribed vazio (audio=\(fmt(buffer.durationSeconds))s "
                           + "peak=\(peak) seguidas=\(consecutiveEmpty)) \(outcome.metricsLine)")
                continuation?.yield(.emptyTranscription)
                if consecutiveEmpty >= 2 {
                    Diag.error(.pipeline, "recovery requested after \(consecutiveEmpty) empty")
                    continuation?.yield(.transcriberRecoveryRequested)
                    // Zera pra não pedir recriação a cada vazio seguinte
                    // enquanto a anterior ainda nem terminou.
                    consecutiveEmpty = 0
                }
                setState(.idle)
                return
            }
            consecutiveEmpty = 0
            Diag.notice(.pipeline, "transcribed \(outcome.metricsLine)")
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
                    Diag.notice(.pipeline, "refiner cancelled (user)")
                    setState(.idle); return
                } catch {
                    Diag.error(.pipeline, "refiner failed (\(refiner.kind.rawValue)): \(String(describing: error))")
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
            if aborted() { Diag.notice(.pipeline, "cancelled after refine"); setState(.idle); return }

            // Histórico ANTES da cola. Com a Acessibilidade caída, o `inject`
            // lançava antes do save e o ditado sumia inteiro: não colava, não
            // ficava no clipboard e não entrava no histórico (S3, auditoria
            // §5.2). O app-alvo é lido agora, enquanto ainda está em foco.
            let frontApp = await injector.frontmostBundleID()
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
                        whisperModelName: await whisperModelNameProvider(),
                        styleName: style.name,
                        frontmostAppBundleID: frontApp),
                    maxItems: maxItems,
                    maxDays:  maxDays)
            } catch {
                Diag.error(.pipeline, "history save failed: \(String(describing: error))")
                continuation?.yield(.historySaveFailed)
            }

            Diag.info(.pipeline, "injecting (kind=\(actualRefinerKind.rawValue))")
            do {
                _ = try await injector.inject(text: refined)
            } catch InjectionError.accessibilityDenied {
                Diag.error(.inject, "AXIsProcessTrusted == false — ditado de \(refined.count) chars "
                           + "não foi colado (está no histórico e no clipboard)")
                continuation?.yield(.permissionDenied(kind: .accessibility))
                setState(.idle)
                return
            } catch {
                Diag.error(.inject, "inject failed: \(String(describing: error))")
                continuation?.yield(.injectionFailed)
                setState(.idle)
                return
            }
            if aborted() { Diag.notice(.pipeline, "cancelled after inject"); setState(.idle); return }
            Diag.notice(.pipeline, "injected to \(frontApp ?? "?") chars=\(refined.count)")

            continuation?.yield(.finished(rawText: raw,
                                          refinedText: refined,
                                          frontmostApp: frontApp))
            setState(.idle)
        } catch {
            Diag.error(.pipeline, "FALHOU: \(String(describing: error))")
            setState(.error(message: "erro no pipeline"))
            continuation?.yield(.errorOccurred(String(describing: error)))
            // Auto-recover pra idle após 2 s — mas só se ainda estivermos em
            // .error. Sem a guarda, um toggle dentro desses 2 s já tinha
            // começado outra gravação e este .idle atrasado derrubava o
            // .recording: o painel sumia, o engine seguia gravando e o toggle
            // seguinte fazia installTap duplo (auditoria §5.1).
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .error = state { setState(.idle) }
        }
    }

    deinit { continuation?.finish() }
}
