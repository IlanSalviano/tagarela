import Foundation
import OSLog

actor PipelineCoordinator {
    private let logger = Logger(subsystem: "com.tagarela", category: "Pipeline")
    private let audio: AudioCapturing
    private let transcriber: Transcribing
    private let refinerProvider: @MainActor @Sendable () -> (refiner: TextRefiner, style: Style)
    private let injector: Injecting
    private let language: String
    private let initialPromptProvider: @Sendable () -> String?

    private(set) var state: PipelineState = .idle
    private var continuation: AsyncStream<PipelineEvent>.Continuation?
    nonisolated let events: AsyncStream<PipelineEvent>

    private var startTime: Date?
    private var currentLevel: Double = 0
    private var recordingTasks: [Task<Void, Never>] = []

    init(audio: AudioCapturing,
         transcriber: Transcribing,
         refinerProvider: @escaping @MainActor @Sendable () -> (refiner: TextRefiner, style: Style),
         injector: Injecting,
         language: String = "pt",
         initialPromptProvider: @escaping @Sendable () -> String? = { nil }) {
        self.audio = audio
        self.transcriber = transcriber
        self.refinerProvider = refinerProvider
        self.injector = injector
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
        FileHandle.standardError.write(Data("[pipeline] toggle in state=\(state)\n".utf8))
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
            } catch {
                setState(.error(message: "mic indisponível"))
                continuation?.yield(.errorOccurred("mic: \(error)"))
            }
        case .recording:
            cancelRecordingTasks()
            await runTranscribeAndInject()
        case .processing, .refining, .error:
            // Ignorado — apenas .cancel é aceito durante esses estados
            break
        }
    }

    private func handleCancel() async {
        switch state {
        case .recording:
            cancelRecordingTasks()
            _ = try? await audio.stop()
            setState(.idle)
        case .processing, .refining:
            // Sem cancel real do whisper na v1 — só marcamos idle e descartamos resultado
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

    private func runTranscribeAndInject() async {
        do {
            FileHandle.standardError.write(Data("[pipeline] stopping audio\n".utf8))
            let buffer = try await audio.stop()
            FileHandle.standardError.write(Data("[pipeline] buffer duration=\(buffer.durationSeconds)s samples=\(buffer.samples.count)\n".utf8))
            guard buffer.durationSeconds >= 0.5 else {
                FileHandle.standardError.write(Data("[pipeline] buffer too short, descartando\n".utf8))
                setState(.idle); return
            }
            setState(.processing)
            FileHandle.standardError.write(Data("[pipeline] transcribing (model loaded? \(transcriber.loadedModelName ?? "NIL"))\n".utf8))
            let raw = try await transcriber.transcribe(
                buffer: buffer,
                language: language,
                initialPrompt: initialPromptProvider()
            )
            FileHandle.standardError.write(Data("[pipeline] transcribed: '\(raw)'\n".utf8))
            setState(.refining)
            let (refiner, style) = await refinerProvider()
            let actualRefinerKind: RefinerKind
            let refined: String
            do {
                refined = try await refiner.refine(raw, style: style)
                actualRefinerKind = refiner.kind
            } catch RefinerError.cancelled {
                // Cancelamento real: aborta sem fallback nem inject
                FileHandle.standardError.write(Data("[pipeline] refiner cancelled\n".utf8))
                setState(.idle); return
            } catch {
                logger.error("refiner failed (\(refiner.kind.rawValue)): \(String(describing: error))")
                let identityFallback = IdentityRefiner()
                refined = (try? await identityFallback.refine(raw, style: style)) ?? raw
                actualRefinerKind = identityFallback.kind
            }
            FileHandle.standardError.write(Data("[pipeline] injecting (kind=\(actualRefinerKind.rawValue))\n".utf8))
            let frontApp = try await injector.inject(text: refined)
            FileHandle.standardError.write(Data("[pipeline] injected to \(frontApp ?? "?")\n".utf8))
            continuation?.yield(.finished(rawText: raw,
                                          refinedText: refined,
                                          frontmostApp: frontApp))
            setState(.idle)
        } catch {
            FileHandle.standardError.write(Data("[pipeline] FALHOU: \(String(describing: error))\n".utf8))
            setState(.error(message: "erro no pipeline"))
            continuation?.yield(.errorOccurred(String(describing: error)))
            // Auto-recover pra idle após 2s
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            setState(.idle)
        }
    }

    deinit { continuation?.finish() }
}
