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

    func test_languageProvider_explicitValue_reachesTranscriber() async {
        let transcriber = LanguageCapturingTranscriber()
        let p = PipelineCoordinator(
            audio: FakeAudio(),
            transcriberProvider: { transcriber },
            refinerProvider: { @MainActor in (IdentityRefiner(), BuiltInStyles.conversaInformal) },
            injector: FakeInjector(),
            historyStore: FakeHistoryStore(),
            historyMaxItemsProvider: { @MainActor in 100 },
            historyMaxDaysProvider: { @MainActor in 30 },
            llmModelNameProvider: { @MainActor _ in nil },
            whisperModelNameProvider: { "fake" },
            languageProvider: { "en" }
        )
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let got = await transcriber.received.get()
        XCTAssertEqual(got, .some("en"),
                       "languageProvider deve chegar como 'en' no transcriber")
    }

    func test_languageProvider_nil_propagatesAsAutoDetect() async {
        let transcriber = LanguageCapturingTranscriber()
        let p = PipelineCoordinator(
            audio: FakeAudio(),
            transcriberProvider: { transcriber },
            refinerProvider: { @MainActor in (IdentityRefiner(), BuiltInStyles.conversaInformal) },
            injector: FakeInjector(),
            historyStore: FakeHistoryStore(),
            historyMaxItemsProvider: { @MainActor in 100 },
            historyMaxDaysProvider: { @MainActor in 30 },
            llmModelNameProvider: { @MainActor _ in nil },
            whisperModelNameProvider: { "fake" },
            languageProvider: { nil }
        )
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let got = await transcriber.received.get()
        // outer .some confirma que transcribe foi chamado; inner nil = auto-detect
        XCTAssertEqual(got, .some(nil),
                       "languageProvider nil deve chegar como nil (auto-detect) no transcriber")
    }

    // Helpers ----------------------------------------------------


    /// Regressão da auditoria §5.1: `levels` era um único `AsyncStream` criado
    /// no init do `AudioCaptureLive`, e `cancelRecordingTasks()` cancelava a
    /// Task consumidora — o que **termina** o stream (provado em
    /// `tools/diag/asyncstream_cancel_test.swift`). Da segunda gravação em
    /// diante nenhum nível chegava: os 4 indicadores animavam com
    /// `audioLevel = 0` para sempre.
    func test_levels_arrive_in_second_recording() async {
        let audio = LevelEmittingAudio()
        let p = makeCoordinator(audio: audio)

        await p.handle(.toggle)
        audio.emit(0.5)
        let first = await waitForLevel(0.5, in: p)
        XCTAssertTrue(first, "1ª gravação deveria receber nível")

        await p.handle(.toggle)                       // encerra e roda o pipeline
        try? await Task.sleep(nanoseconds: 200_000_000)

        await p.handle(.toggle)                       // 2ª gravação
        audio.emit(0.5)
        let second = await waitForLevel(0.5, in: p)
        XCTAssertTrue(second, "2ª gravação também precisa receber níveis")
    }

    private func waitForLevel(_ expected: Double,
                              in p: PipelineCoordinator,
                              timeoutMs: Int = 1_000) async -> Bool {
        for _ in 0..<(timeoutMs / 20) {
            if case .recording(_, let level) = await p.state, level == expected { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return false
    }


    // MARK: - Fase 5: falhas visíveis, recuperação e corridas

    /// S1 da auditoria §3.4: gravação de verdade que não rendeu áudio era
    /// descartada sem evento, toast, histórico ou log de erro.
    func test_tooShortAfterLongRecording_emitsCaptureFailed() async {
        let clock = MutableClock()
        let p = makeCoordinator(audio: FixedBufferAudio(seconds: 0.2), now: { clock.now })
        let events = collectEvents(from: p)

        await p.handle(.toggle)
        clock.advance(2.0)                        // gravou 2 s de relógio
        await p.handle(.toggle)

        let got = await waitForEvent(events) {
            if case .captureFailed(.tooShort) = $0 { return true }
            return false
        }
        XCTAssertTrue(got, "gravação longa sem áudio tem que virar evento visível")
        let finalState = await p.state
        XCTAssertEqual(finalState, .idle)
    }

    /// Contraponto: um toque acidental na hotkey não pode virar toast.
    func test_tooShortAfterTapRecording_isSilent() async {
        let clock = MutableClock()
        let p = makeCoordinator(audio: FixedBufferAudio(seconds: 0.2), now: { clock.now })
        let events = collectEvents(from: p)

        await p.handle(.toggle)
        clock.advance(0.3)                        // toque acidental
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let noisy = await events.contains {
            if case .captureFailed = $0 { return true }
            return false
        }
        XCTAssertFalse(noisy, "toque acidental na hotkey não pode gerar toast")
        let finalState = await p.state
        XCTAssertEqual(finalState, .idle)
    }

    func test_audioStopThrowsNoAudioDelivered_emitsCaptureFailed() async {
        let p = makeCoordinator(audio: NoAudioDeliveredAudio())
        let events = collectEvents(from: p)

        await p.handle(.toggle)
        await p.handle(.toggle)

        let got = await waitForEvent(events) {
            if case .captureFailed(.noAudio) = $0 { return true }
            return false
        }
        XCTAssertTrue(got, "stop() lançando noAudioDelivered tem que virar captureFailed")
        let finalState = await p.state
        XCTAssertEqual(finalState, .idle)
    }

    /// S2: texto vazio era injetado (colava "nada" no app-alvo) e salvo no
    /// histórico, poluindo os dois sem sinal nenhum de degradação.
    func test_emptyTranscription_doesNotInjectNorSave_emitsEvent() async {
        let injector = FakeInjector()
        let history = FakeHistoryStore()
        let p = makeCoordinator(injector: injector, history: history,
                                transcriber: { EmptyTranscriber() })
        let events = collectEvents(from: p)

        await p.handle(.toggle)
        await p.handle(.toggle)

        let got = await waitForEvent(events) { $0 == .emptyTranscription }
        XCTAssertTrue(got, "transcrição vazia tem que emitir evento")
        XCTAssertNil(injector.injected, "vazio não pode ser injetado")
        XCTAssertTrue(history.saved.isEmpty, "vazio não pode poluir o histórico")
    }

    func test_twoConsecutiveEmpty_requestsRecovery() async {
        let p = makeCoordinator(transcriber: { EmptyTranscriber() })
        let events = collectEvents(from: p)

        await p.handle(.toggle); await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        await p.handle(.toggle); await p.handle(.toggle)

        let got = await waitForEvent(events) { $0 == .transcriberRecoveryRequested }
        XCTAssertTrue(got, "dois vazios seguidos têm que pedir recriação do transcriber")
    }

    func test_successResetsConsecutiveEmpty() async {
        let transcriber = SwitchableTranscriber(text: "")
        let p = makeCoordinator(transcriber: { transcriber })
        let events = collectEvents(from: p)

        await p.handle(.toggle); await p.handle(.toggle)     // 1º vazio
        try? await Task.sleep(nanoseconds: 200_000_000)
        transcriber.text = "olá mundo"
        await p.handle(.toggle); await p.handle(.toggle)     // sucesso zera
        try? await Task.sleep(nanoseconds: 200_000_000)
        transcriber.text = ""
        await p.handle(.toggle); await p.handle(.toggle)     // vazio de novo, mas isolado
        try? await Task.sleep(nanoseconds: 300_000_000)

        let asked = await events.contains { $0 == .transcriberRecoveryRequested }
        XCTAssertFalse(asked, "um sucesso no meio zera a sequência de vazios")
    }

    /// Corrida da auditoria §5.1: o `.idle` atrasado do auto-recover
    /// sobrescrevia o `.recording` de uma gravação nova, o painel sumia e o
    /// engine continuava gravando — o próximo toggle dava installTap duplo.
    func test_errorAutoRecover_doesNotClobberNewRecording() async {
        let audio = FailThenSucceedAudio()
        let p = makeCoordinator(audio: audio)

        await p.handle(.toggle)                    // start falha → .error
        var isError = false
        if case .error = await p.state { isError = true }
        XCTAssertTrue(isError, "start falho deveria levar a .error")

        audio.shouldFail = false
        await p.handle(.toggle)                    // recovery: começa a gravar
        try? await Task.sleep(nanoseconds: 2_500_000_000)   // passa dos 2 s do auto-recover

        var stillRecording = false
        if case .recording = await p.state { stillRecording = true }
        XCTAssertTrue(stillRecording,
                      "o .idle atrasado do auto-recover não pode derrubar a gravação nova")
    }

    /// Esc durante "transcrevendo" deixava um transcribe() em vôo; um toggle
    /// imediato começava outro na MESMA instância WhisperKit.
    func test_toggleAfterCancelWaitsForPreviousPipelineTask() async {
        let audio = CountingStartAudio()
        let p = makeCoordinator(audio: audio, transcriber: { SlowTranscriber(delayMs: 600) })

        await p.handle(.toggle)                    // grava
        await p.handle(.toggle)                    // → .processing (transcribe lento)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await p.handle(.cancel)                    // Esc: volta a .idle, task segue em vôo
        await p.handle(.toggle)                    // toggle imediato

        XCTAssertEqual(audio.starts, 2, "a segunda gravação só pode começar depois da anterior")
        let previousTask = await p.pipelineTask
        let previousFinished = previousTask == nil
        XCTAssertTrue(previousFinished || audio.starts == 2,
                      "o toggle esperou a pipeline anterior terminar")
    }

    /// S3: com a Acessibilidade caída o ditado sumia inteiro — não colava, não
    /// ficava no clipboard e não entrava no histórico.
    func test_historySavedEvenWhenInjectFails() async {
        let injector = FakeInjector()
        injector.injectError = InjectionError.accessibilityDenied
        let history = FakeHistoryStore()
        let p = makeCoordinator(injector: injector, history: history)

        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(history.saved.count, 1, "o ditado tem que ser salvo mesmo com a cola falhando")
        XCTAssertEqual(history.saved.first?.rawText, "olá mundo")
    }


    /// Campo: no primeiro launch após o upgrade para macOS 27, o CoreML
    /// recompilou o modelo para a ANE e a carga levou **94 s** (contra ~13 s
    /// num launch normal). Cada hotkey nessa janela gravava 4 segundos de fala
    /// e devolvia "erro no pipeline", sem dizer que era só cedo demais — e o
    /// usuário concluiu, razoavelmente, que o app tinha quebrado.
    func test_toggleBeforeModelLoads_doesNotRecordAndSaysSo() async {
        let audio = CountingStartAudio()
        let p = makeCoordinator(audio: audio, transcriber: { UnloadedTranscriber() })
        let events = collectEvents(from: p)

        await p.handle(.toggle)

        let told = await waitForEvent(events) { $0 == .transcriberNotReady }
        XCTAssertTrue(told, "o usuário precisa ouvir que o modelo ainda está carregando")
        XCTAssertEqual(audio.starts, 0, "não pode gravar 4 s de fala que será descartada")
        let state = await p.state
        XCTAssertEqual(state, .idle, "não é erro do pipeline — é cedo demais")
    }

    // MARK: - helpers da Fase 5

    private func collectEvents(from p: PipelineCoordinator) -> EventCollector {
        let collector = EventCollector()
        Task { for await event in p.events { await collector.add(event) } }
        return collector
    }

    private func waitForEvent(_ collector: EventCollector,
                              timeoutMs: Int = 2_000,
                              where predicate: @escaping @Sendable (PipelineEvent) -> Bool) async -> Bool {
        for _ in 0..<(timeoutMs / 20) {
            if await collector.contains(predicate) { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return false
    }

    private func makeCoordinator(audio: AudioCapturing = FakeAudio(),
                                 refiner: TextRefiner = IdentityRefiner(),
                                 style: Style = BuiltInStyles.conversaInformal,
                                 injector: Injecting = FakeInjector(),
                                 history: FakeHistoryStore = FakeHistoryStore(),
                                 transcriber: @escaping @MainActor @Sendable () -> Transcribing = { FakeTranscriber() },
                                 now: @escaping @Sendable () -> Date = { Date() }) -> PipelineCoordinator {
        PipelineCoordinator(
            audio: audio,
            transcriberProvider: transcriber,
            refinerProvider: { @MainActor in (refiner, style) },
            injector: injector,
            historyStore: history,
            historyMaxItemsProvider: { @MainActor in 100 },
            historyMaxDaysProvider: { @MainActor in 30 },
            llmModelNameProvider: { @MainActor _ in nil },
            whisperModelNameProvider: { "fake" },
            now: now
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

/// Espelha o contrato de `AudioCapturing.levels`: um stream **por gravação**,
/// criado no `start()` e finalizado no `stop()`.
private final class LevelEmittingAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    private(set) var levels = AsyncStream<Double> { $0.finish() }
    private var continuation: AsyncStream<Double>.Continuation?

    func emit(_ value: Double) { continuation?.yield(value) }

    func start() throws {
        let (stream, continuation) = AsyncStream<Double>.makeStream(of: Double.self)
        self.levels = stream
        self.continuation = continuation
        isRecording = true
    }

    func stop() async throws -> AudioBuffer {
        isRecording = false
        continuation?.finish()
        continuation = nil
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000), sampleRate: 16_000)
    }
}

// MARK: - fakes da Fase 5

private actor EventCollector {
    private var events: [PipelineEvent] = []
    func add(_ event: PipelineEvent) { events.append(event) }
    func contains(_ predicate: @Sendable (PipelineEvent) -> Bool) -> Bool {
        events.contains(where: predicate)
    }
}

/// Relógio controlado pelo teste. Evita `sleep` de segundos só para atravessar
/// o limiar de wall-clock — a auditoria §5.5 já reclamava dos sleeps fixos.
private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) {
        lock.lock(); value = value.addingTimeInterval(seconds); lock.unlock()
    }
    var now: Date { lock.lock(); defer { lock.unlock() }; return value }
}

/// Devolve sempre um buffer de duração fixa, independente do tempo gravado.
private final class FixedBufferAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    let levels = AsyncStream<Double> { $0.finish() }
    private let seconds: Double
    init(seconds: Double) { self.seconds = seconds }
    func start() throws { isRecording = true }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: Int(16_000 * seconds)),
                           sampleRate: 16_000)
    }
}

private final class NoAudioDeliveredAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    let levels = AsyncStream<Double> { $0.finish() }
    func start() throws { isRecording = true }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        throw AudioCaptureError.noAudioDelivered
    }
}

private final class FailThenSucceedAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    var shouldFail = true
    let levels = AsyncStream<Double> { $0.finish() }
    func start() throws {
        if shouldFail { throw AudioCaptureError.engineFailedToStart }
        isRecording = true
    }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000), sampleRate: 16_000)
    }
}

private final class CountingStartAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    private let lock = NSLock()
    private var startCount = 0
    var starts: Int { lock.lock(); defer { lock.unlock() }; return startCount }
    let levels = AsyncStream<Double> { $0.finish() }
    func start() throws {
        lock.lock(); startCount += 1; lock.unlock()
        isRecording = true
    }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000), sampleRate: 16_000)
    }
}

private final class UnloadedTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String?          // nil = ainda carregando
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        throw TranscribeError.modelNotLoaded
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
}

private final class EmptyTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        TranscriptionOutcome(text: "")
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
}

private final class SwitchableTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    private let lock = NSLock()
    private var value: String
    var text: String {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
    init(text: String) { self.value = text }
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        TranscriptionOutcome(text: text)
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
}

private final class SlowTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    private let delayMs: Int
    init(delayMs: Int) { self.delayMs = delayMs }
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        return TranscriptionOutcome(text: "olá mundo")
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
}

private final class FakeTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        TranscriptionOutcome(text: "olá mundo")
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
}

/// Captura o `language` recebido pra validar a propagação do languageProvider.
private final class LanguageCapturingTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    let received = ActorOptionalString()
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        await received.set(language)
        return TranscriptionOutcome(text: "olá mundo")
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
}

private actor ActorOptionalString {
    private var v: String??  // outer nil = nunca chamado; inner nil = auto
    func set(_ value: String?) { v = value }
    func get() -> String?? { v }
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
    func transcribe(buffer: AudioBuffer, language: String?, initialPrompt: String?) async throws -> TranscriptionOutcome {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        return TranscriptionOutcome(text: "olá mundo")
    }
    func unloadModel() { loadedModelName = nil }
    func reload() async throws {}
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
