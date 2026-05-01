import XCTest
@testable import Tagarela

final class PipelineCoordinatorTests: XCTestCase {
    func test_toggleFromIdle_movesToRecording() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        let s = await p.state
        if case .recording = s {} else { XCTFail("expected recording, got \(s)") }
    }

    func test_toggleFromRecording_runsPipelineAndReturnsToIdle() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        await p.handle(.toggle)
        // dar tempo da pipeline rodar (fakes são síncronos suficientes)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    func test_cancelDuringRecording_returnsToIdle() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        await p.handle(.cancel)
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    func test_refinerFails_fallsBackToIdentity() async {
        let p = makeCoordinator(refiner: FakeRefiner(kind: .openai, result: .failure(RefinerError.networkOffline)))
        let received = collectFinished(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let r = await received.value
        XCTAssertEqual(r?.refinedText, "olá mundo", "fallback Identity should pass through raw text")
    }

    func test_cancelledError_withoutUserCancelFlag_treatedAsNetworkDrop() async {
        // RefinerError.cancelled SEM flag `cancelled` ligada significa
        // network-drop disfarçado (URLSession -999 quando remote termina
        // conexão abruptamente, ex: `pkill ollama`). Pipeline trata como
        // fallback → emit .refinerFellBack(.networkOffline) + identity
        // passthrough. Bug encontrado no aceite manual da Fase 2b-2.
        let p = makeCoordinator(refiner: FakeRefiner(kind: .openai, result: .failure(RefinerError.cancelled)))
        let received = collectFinished(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let r = await received.value
        XCTAssertEqual(r?.refinedText, "olá mundo",
                       "cancelled-from-refiner sem flag user-cancel deve cair em identity fallback")
    }

    func test_identityRefiner_skipsRefiningState() async {
        let p = makeCoordinator(refiner: IdentityRefiner())
        let states = collectStates(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let collected = await states.value
        // Esperado: idle, recording, processing, idle (sem .refining)
        XCTAssertFalse(collected.contains { if case .refining = $0 { return true } else { return false } },
                       "Identity should skip .refining; collected: \(collected)")
    }

    func test_pipelineSuccess_savesHistory() async {
        let history = FakeHistoryStore()
        let p = makeCoordinator(refiner: IdentityRefiner(), history: history)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(history.saved.count, 1)
        XCTAssertEqual(history.saved.first?.rawText, "olá mundo")
        XCTAssertEqual(history.saved.first?.refinedText, "olá mundo")
        XCTAssertEqual(history.saved.first?.refinerKind, "none")
    }

    func test_pipelineCancel_doesNotSaveHistory() async {
        let history = FakeHistoryStore()
        let p = makeCoordinator(refiner: IdentityRefiner(), history: history)
        await p.handle(.toggle)
        await p.handle(.cancel)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(history.saved.count, 0)
    }

    func test_cancelDuringProcessing_doesNotCallRefiner() async {
        // FakeTranscriber atual retorna instantâneo, então cancel ANTES de
        // entrar em refine é difícil de programar deterministicamente.
        // Estratégia: refiner que conta calls; cancel logo após toggle final;
        // dar pouco tempo (50ms) — se o cancel chega antes do refine ser
        // chamado, count == 0. Se chega depois, conta 1 (test fica flaky).
        // Pra garantir: usar transcriber lento.
        let slowTranscriber = FakeTranscriberSlow()
        let counted = CountingRefiner(kind: .openai)
        let p = PipelineCoordinator(
            audio: FakeAudio(),
            transcriberProvider: { slowTranscriber },
            refinerProvider: { @MainActor in (counted, BuiltInStyles.conversaInformal) },
            injector: FakeInjector(),
            historyStore: FakeHistoryStore(),
            historyMaxItemsProvider: { @MainActor in 100 },
            historyMaxDaysProvider: { @MainActor in 30 },
            llmModelNameProvider: { @MainActor _ in nil },
            whisperModelNameProvider: { "fake" }
        )
        await p.handle(.toggle)
        await p.handle(.toggle)
        // Em .processing — cancel antes do transcribe completar
        try? await Task.sleep(nanoseconds: 100_000_000)
        await p.handle(.cancel)
        try? await Task.sleep(nanoseconds: 1_500_000_000) // > slow transcribe
        let count = await counted.callCount.get()
        XCTAssertEqual(count, 0,
                       "refiner não deve ser chamado quando cancel ocorre em .processing")
    }

    func test_cancelDuringRefining_doesNotInject() async {
        let slow = FakeRefinerSlow(kind: .openai)
        let injector = FakeInjector()
        let p = makeCoordinator(refiner: slow, injector: injector)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await p.handle(.cancel)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(injector.injected,
                     "inject não deve acontecer quando cancel ocorre em .refining")
    }

    func test_cancelDuringRefining_doesNotSaveHistory() async {
        let slow = FakeRefinerSlow(kind: .openai)
        let history = FakeHistoryStore()
        let p = makeCoordinator(refiner: slow, history: history)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await p.handle(.cancel)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(history.saved.count, 0,
                       "history não deve ser salvo quando cancel ocorre em .refining")
    }

    func test_pipelineTask_clearedAfterCompletion() async {
        // Sentinela em duas fases: pipelineTask deve ser não-nil durante
        // o processamento (FakeTranscriberSlow segura em .processing por 1s)
        // E voltar a nil após completion. Sem o non-nil mid-check, o teste
        // passaria também se pipelineTask nunca fosse atribuído.
        let p = PipelineCoordinator(
            audio: FakeAudio(),
            transcriberProvider: { FakeTranscriberSlow() },
            refinerProvider: { @MainActor in (IdentityRefiner(), BuiltInStyles.conversaInformal) },
            injector: FakeInjector(),
            historyStore: FakeHistoryStore(),
            historyMaxItemsProvider: { @MainActor in 100 },
            historyMaxDaysProvider: { @MainActor in 30 },
            llmModelNameProvider: { @MainActor _ in nil },
            whisperModelNameProvider: { "fake" }
        )
        await p.handle(.toggle)  // → recording
        await p.handle(.toggle)  // → processing (transcriber segura por 1s)
        // 200ms basta pra Task ser atribuída e transcribe começar
        try? await Task.sleep(nanoseconds: 200_000_000)
        let mid = await p.pipelineTask
        XCTAssertNotNil(mid, "pipelineTask deve estar setado durante .processing")
        // Aguardar o pipeline completar (1s do transcribe + folga)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        let after = await p.pipelineTask
        XCTAssertNil(after, "pipelineTask deve ser limpo após runTranscribeAndInject completar")
    }

    func test_cancelDuringRefining_cancelsRefinerTask() async {
        // Refiner lento + cooperative cancel: a única forma do
        // wasCancelled virar true é se Task.cancel() se propagar
        // até o sleep do refiner. Hoje (sem pipelineTask), não propaga.
        let slow = FakeRefinerSlow(kind: .openai)
        let p = makeCoordinator(refiner: slow)
        await p.handle(.toggle)
        await p.handle(.toggle)
        // dar 100ms pra entrar em .refining
        try? await Task.sleep(nanoseconds: 100_000_000)
        await p.handle(.cancel)
        // dar 100ms pro cancellation se propagar e estado ir pra idle
        try? await Task.sleep(nanoseconds: 200_000_000)
        let s = await p.state
        XCTAssertEqual(s, .idle)
        let wasCancelled = await slow.cancelledBox.get()
        XCTAssertTrue(wasCancelled,
                      "Task.cancel() deve propagar até o refiner.refine sleep")
    }

    // Helpers ----------------------------------------------------

    private func makeCoordinator(audio: AudioCapturing = FakeAudio(),
                                 refiner: TextRefiner = IdentityRefiner(),
                                 style: Style = BuiltInStyles.conversaInformal,
                                 injector: Injecting = FakeInjector(),
                                 history: FakeHistoryStore = FakeHistoryStore()) -> PipelineCoordinator {
        PipelineCoordinator(
            audio: audio,
            transcriberProvider: { FakeTranscriber() },
            refinerProvider: { @MainActor in (refiner, style) },
            injector: injector,
            historyStore: history,
            historyMaxItemsProvider: { @MainActor in 100 },
            historyMaxDaysProvider: { @MainActor in 30 },
            llmModelNameProvider: { @MainActor _ in nil },
            whisperModelNameProvider: { "fake" }
        )
    }

    private func collectFinished(from p: PipelineCoordinator) -> Task<(rawText: String, refinedText: String, frontmostApp: String?)?, Never> {
        Task {
            for await ev in p.events {
                if case let .finished(raw, refined, app) = ev {
                    return (raw, refined, app)
                }
                if case .stateChanged(.idle) = ev {
                    // .idle reached without .finished — provavelmente cancel/error
                    return nil
                }
            }
            return nil
        }
    }

    private func collectStates(from p: PipelineCoordinator) -> Task<[PipelineState], Never> {
        Task {
            var collected: [PipelineState] = []
            for await ev in p.events {
                if case .stateChanged(let s) = ev {
                    collected.append(s)
                    if case .idle = s, collected.count > 1 { break }
                }
            }
            return collected
        }
    }

    func test_refinerFails_emitsRefinerFellBackWithReason() async {
        let p = makeCoordinator(refiner: FakeRefiner(kind: .openai, result: .failure(RefinerError.networkOffline)))
        let captured = collectFallback(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let reason = await captured.value
        XCTAssertEqual(reason, .networkOffline)
    }

    func test_injectFails_emitsInjectionFailed() async {
        let injector = FakeInjector()
        injector.injectError = NSError(domain: "test", code: 1)
        let p = makeCoordinator(refiner: IdentityRefiner(), injector: injector)
        let captured = collectInjectionFailed(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let result = await captured.value
        XCTAssertTrue(result)
    }

    func test_saveFails_emitsHistorySaveFailed() async {
        let history = FakeHistoryStore()
        history.saveError = NSError(domain: "test", code: 2)
        let p = makeCoordinator(refiner: IdentityRefiner(), history: history)
        let captured = collectHistorySaveFailed(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let result = await captured.value
        XCTAssertTrue(result)
    }

    func test_micDenied_emitsPermissionDeniedMicrophone() async {
        let audio = FakeAudio()
        audio.startError = AudioCaptureError.microphoneDenied
        let p = makeCoordinator(audio: audio)
        let captured = collectPermissionDenied(from: p)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let kind = await captured.value
        XCTAssertEqual(kind, .microphone)
    }

    private func collectFallback(from p: PipelineCoordinator) -> Task<RefinerFallbackReason?, Never> {
        Task {
            for await ev in p.events {
                if case .refinerFellBack(let reason) = ev { return reason }
                if case .stateChanged(.idle) = ev { return nil }
            }
            return nil
        }
    }

    private func collectInjectionFailed(from p: PipelineCoordinator) -> Task<Bool, Never> {
        Task {
            for await ev in p.events {
                if case .injectionFailed = ev { return true }
                // .finished não é emitido no path de inject error (return early
                // após setState(.idle)). Sentinel real é .stateChanged(.idle).
                if case .stateChanged(.idle) = ev { return false }
            }
            return false
        }
    }

    private func collectHistorySaveFailed(from p: PipelineCoordinator) -> Task<Bool, Never> {
        Task {
            for await ev in p.events {
                if case .historySaveFailed = ev { return true }
                if case .stateChanged(.idle) = ev { return false }
            }
            return false
        }
    }

    private func collectPermissionDenied(from p: PipelineCoordinator) -> Task<PermissionKind?, Never> {
        Task {
            for await ev in p.events {
                if case .permissionDenied(let kind) = ev { return kind }
                if case .stateChanged(.idle) = ev { return nil }
            }
            return nil
        }
    }
}

actor ActorBool {
    private var v: Bool = false
    func set(_ b: Bool) { v = b }
    func get() -> Bool { v }
}

private final class FakeRefiner: TextRefiner, @unchecked Sendable {
    let kind: RefinerKind
    let result: Result<String, Error>
    let onCalled: (@Sendable () async -> Void)?

    init(kind: RefinerKind, result: Result<String, Error>, onCalled: (@Sendable () async -> Void)? = nil) {
        self.kind = kind
        self.result = result
        self.onCalled = onCalled
    }

    func refine(_ raw: String, style: Style) async throws -> String {
        await onCalled?()
        switch result {
        case .success(let s): return s
        case .failure(let e): throw e
        }
    }
}

private final class FakeAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    let levels = AsyncStream<Double> { _ in }
    var startError: Error?   // NEW
    func start() throws {
        if let e = startError { throw e }
        isRecording = true
    }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000), sampleRate: 16_000)
    }
}

private final class FakeTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        "olá mundo"
    }
    func unloadModel() { loadedModelName = nil }
}

private final class FakeInjector: Injecting, @unchecked Sendable {
    var injected: String?
    var injectError: Error?   // NEW
    func inject(text: String) async throws -> String? {
        if let e = injectError { throw e }
        injected = text
        return "com.example.app"
    }
}

private final class FakeHistoryStore: HistoryStore, @unchecked Sendable {
    var saved: [TranscriptionInput] = []
    var saveError: Error?   // NEW
    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {
        if let e = saveError { throw e }
        saved.append(input)
    }
    func recent(limit: Int) async throws -> [Transcription] { [] }
    func clearAll() async throws { saved.removeAll() }
}

private final class FakeRefinerSlow: TextRefiner, @unchecked Sendable {
    let kind: RefinerKind
    /// Sinaliza que o sleep foi interrompido por cancellation cooperativa.
    /// Lê via @MainActor wrapper pra atravessar boundary do actor pipeline.
    let cancelledBox = ActorBool()

    init(kind: RefinerKind = .openai) { self.kind = kind }

    func refine(_ raw: String, style: Style) async throws -> String {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            return "refined"
        } catch is CancellationError {
            await cancelledBox.set(true)
            throw RefinerError.cancelled
        }
    }
}

private final class FakeTranscriberSlow: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        return "olá mundo"
    }
    func unloadModel() { loadedModelName = nil }
}

private actor ActorInt {
    private var v: Int = 0
    func inc() { v += 1 }
    func get() -> Int { v }
}

private final class CountingRefiner: TextRefiner, @unchecked Sendable {
    let kind: RefinerKind
    let callCount = ActorInt()
    init(kind: RefinerKind) { self.kind = kind }
    func refine(_ raw: String, style: Style) async throws -> String {
        await callCount.inc()
        return "refined"
    }
}
