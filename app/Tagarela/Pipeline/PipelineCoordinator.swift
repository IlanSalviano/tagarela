import Foundation
import OSLog

actor PipelineCoordinator {
    private let logger = Logger(subsystem: "com.tagarela", category: "Pipeline")
    private let audio: AudioCapturing
    private let transcriber: Transcribing
    private let refiner: TextRefiner
    private let injector: Injecting
    private let language: String
    private let initialPromptProvider: @Sendable () -> String?

    private(set) var state: PipelineState = .idle
    private var continuation: AsyncStream<PipelineEvent>.Continuation?
    nonisolated let events: AsyncStream<PipelineEvent>

    init(audio: AudioCapturing,
         transcriber: Transcribing,
         refiner: TextRefiner,
         injector: Injecting,
         language: String = "pt",
         initialPromptProvider: @escaping @Sendable () -> String? = { nil }) {
        self.audio = audio
        self.transcriber = transcriber
        self.refiner = refiner
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
        switch state {
        case .idle:
            do {
                try audio.start()
                setState(.recording(elapsedSeconds: 0, audioLevel: 0))
            } catch {
                setState(.error(message: "mic indisponível"))
                continuation?.yield(.errorOccurred("mic: \(error)"))
            }
        case .recording:
            await runTranscribeAndInject()
        case .processing, .refining, .error:
            // Ignorado — apenas .cancel é aceito durante esses estados
            break
        }
    }

    private func handleCancel() async {
        switch state {
        case .recording:
            _ = try? await audio.stop()
            setState(.idle)
        case .processing, .refining:
            // Sem cancel real do whisper na v1 — só marcamos idle e descartamos resultado
            setState(.idle)
        case .idle, .error:
            break
        }
    }

    private func runTranscribeAndInject() async {
        do {
            let buffer = try await audio.stop()
            guard buffer.durationSeconds >= 0.5 else {
                setState(.idle); return
            }
            setState(.processing)
            let raw = try await transcriber.transcribe(
                buffer: buffer,
                language: language,
                initialPrompt: initialPromptProvider()
            )
            setState(.refining)
            let refined = try await refiner.refine(raw, style: "cru — sem reescrita")
            let frontApp = try await injector.inject(text: refined)
            continuation?.yield(.finished(rawText: raw,
                                          refinedText: refined,
                                          frontmostApp: frontApp))
            setState(.idle)
        } catch {
            setState(.error(message: "erro no pipeline"))
            continuation?.yield(.errorOccurred(String(describing: error)))
            // Auto-recover pra idle após 2s
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            setState(.idle)
        }
    }

    deinit { continuation?.finish() }
}
