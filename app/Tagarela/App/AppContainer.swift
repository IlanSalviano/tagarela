import SwiftUI
import AppKit
import AVFoundation
import Combine
import SwiftData
import Sparkle

@MainActor
final class AppContainer: ObservableObject {
    let appState = AppState()
    let health = PipelineHealth()
    let preferencesNavigator = PreferencesNavigator()
    private var isRecoveringTranscriber = false
    let permissions: PermissionService
    var transcriber: Transcribing
    let audio: AudioCapturing
    let injector: Injecting
    let prefs: PreferencesStore
    let keychain: KeychainService
    let healthChecker: OllamaHealthChecker
    let refinerFactory: RefinerFactory
    let hotkeyService: HotkeyService
    let pipeline: PipelineCoordinator
    let onboarding: OnboardingCoordinator
    let indicatorPanel = FloatingIndicatorPanel()
    let historyStore: HistoryStore
    let customStyleStore: CustomStyleStore
    /// Armazenamento do CustomStyleStore.Live concreto, quando disponível.
    /// `nil` quando o ModelContainer falhou e estamos em Noop. UI components
    /// que precisam de @Published (StyleSubmenu, StylesView na T11) observam
    /// este. Components que só precisam do contrato CRUD usam `customStyleStore`.
    let customStyleStoreLive: CustomStyleStoreLive?
    let styleProvider: StyleProvider
    let recentsProvider: RecentTranscriptionsProvider
    let keyPromptWindow: OpenAIKeyPromptWindow
    let preferencesWindow = PreferencesWindow()
    let toastCenter = ToastCenter()
    let updaterController: SPUStandardUpdaterController
    let updates: CheckForUpdatesModel
    /// T9: `swapActive` troca o ponteiro real do transcriber neste container
    /// (e atualiza o `TranscriberRef` compartilhado com o pipeline). Inicializado
    /// em duas fases no init: stub primeiro (pra satisfazer ordem de init),
    /// depois reescrito com o coordinator real que captura `[weak self]`.
    var swapCoordinator: WhisperModelSwapCoordinator
    let modelStore: WhisperModelStore = WhisperModelStoreLive()
    private var cancellables: Set<AnyCancellable> = []

    @Published var showOnboarding: Bool

    init() {
        let permissions = PermissionServiceLive()
        let transcriber = WhisperKitTranscriber()
        let injector = InjectorLive()
        let hotkeyService = HotkeyServiceLive()

        // Migration (T9): se whisperModelName ainda não existe em UserDefaults
        // E tem modelo já em disco, preserva o que está em disco. Evita download
        // surpresa em users existentes que vinham do hardcoded "large-v3".
        // Novo install: chave ausente + nada em disco → default
        // PreferencesDefaults.whisperModelName ("large-v3_turbo") aplica.
        let migrationStore = WhisperModelStoreLive()
        let userDefaults = UserDefaults.standard
        if userDefaults.string(forKey: PreferencesKey.whisperModelName) == nil {
            for candidate in ["large-v3", "medium", "small", "large-v3-turbo", "large-v3_turbo"] {
                if migrationStore.isDownloaded(candidate) {
                    userDefaults.set(candidate, forKey: PreferencesKey.whisperModelName)
                    Diag.notice(.app, "migration: preserved existing model on disk: \(candidate)")
                    break
                }
            }
        }

        let prefs = PreferencesStore(defaults: .standard, defaultStyleID: BuiltInStyles.defaultStyleID)
        let audio = AudioCaptureLive(
            maxGainProvider: { @MainActor [weak prefs] in
                prefs?.audioBoostMaxGain ?? PreferencesDefaults.audioBoostMaxGain
            } as @Sendable () -> Float)
        if prefs.technicalVocabulary.isEmpty {
            prefs.technicalVocabulary = DefaultVocabulary.terms
        }
        let keychain: KeychainService = KeychainServiceLive()
        let session = URLSession.shared
        let healthChecker = OllamaHealthChecker(
            session: session,
            baseURL: URL(string: prefs.ollamaBaseURL) ?? URL(string: "http://localhost:11434")!)
        // Container SwiftData compartilhado entre HistoryStoreLive e CustomStyleStoreLive.
        // Falha → ambos caem em Noop. (Fase 2b-1)
        let sharedContainer: ModelContainer? = try? HistoryStoreLive.sharedContainer()

        let historyStore: HistoryStore
        if let c = sharedContainer {
            historyStore = HistoryStoreLive(container: c)
        } else {
            historyStore = HistoryStoreNoop()
        }

        let customStyleStore: CustomStyleStore
        if let c = sharedContainer {
            customStyleStore = CustomStyleStoreLive(container: c) { [weak prefs] deletedID in
                guard let prefs else { return }
                if prefs.selectedStyleID == deletedID {
                    prefs.selectedStyleID = BuiltInStyles.defaultStyleID
                }
            }
        } else {
            customStyleStore = CustomStyleStoreNoop()
        }

        let styleProvider = StyleProvider(customStore: customStyleStore)

        // weak prefs: defesa contra deallocação prematura. Na prática, AppContainer
        // vive durante toda a vida do app, então fatalError aqui é inalcançável.
        let factory = RefinerFactory(
            prefs: prefs,
            styleProvider: styleProvider,
            openAI: { [weak prefs, keychain] in
                guard let prefs else { fatalError("prefs deallocated") }
                return OpenAIRefiner(session: session,
                                     keychain: keychain,
                                     baseURL: prefs.openAIEndpoint.baseURL,
                                     model: prefs.openAIModel,
                                     timeoutSec: prefs.refinerTimeoutSec)
            },
            ollama: { [weak prefs, healthChecker] in
                guard let prefs else { fatalError("prefs deallocated") }
                return OllamaRefiner(
                    session: session,
                    baseURL: URL(string: prefs.ollamaBaseURL) ?? URL(string: "http://localhost:11434")!,
                    model: prefs.ollamaModel,
                    timeoutSec: prefs.refinerTimeoutSec,
                    healthChecker: healthChecker)
            })

        let keyPromptWindow = OpenAIKeyPromptWindow(keychain: keychain)
        let recentsProvider = RecentTranscriptionsProvider(store: historyStore, limit: 5)

        self.permissions = permissions
        self.transcriber = transcriber
        self.audio = audio
        self.injector = injector
        self.prefs = prefs
        self.keychain = keychain
        self.healthChecker = healthChecker
        self.refinerFactory = factory
        self.hotkeyService = hotkeyService
        self.historyStore = historyStore
        self.customStyleStore = customStyleStore
        self.customStyleStoreLive = customStyleStore as? CustomStyleStoreLive
        self.styleProvider = styleProvider
        self.recentsProvider = recentsProvider
        self.keyPromptWindow = keyPromptWindow
        // Stub temporário pra satisfazer o init — a referência real (com swapActive
        // capturando [weak self]) é instalada logo abaixo, antes de qualquer
        // wiring que use swapCoordinator.
        self.swapCoordinator = WhisperModelSwapCoordinator(
            initialActive: prefs.whisperModelName,
            stagingFactory: { WhisperKitTranscriber() },
            swapActive: { newActive in newActive }
        )
        self.onboarding = OnboardingCoordinator(
            permissionService: permissions, transcriber: transcriber, prefs: prefs
        )
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingCompleted")

        // T9: TranscriberRef é compartilhado entre AppContainer (que mantém
        // `self.transcriber` em sincronia pra onboarding/finishOnboarding e UI)
        // e o pipeline + swap coordinator. Pipeline lê o ponteiro atual via
        // ref.current (resolve em runtime, vê o swap). Swap coordinator
        // escreve em ref.current via swapActive (mais o `self.transcriber`).
        let transcriberRef = TranscriberRef(transcriber)
        self.pipeline = PipelineCoordinator(
            audio: audio,
            transcriberProvider: { transcriberRef.current },
            refinerProvider: { factory.current() },
            injector: injector,
            historyStore: historyStore,
            historyMaxItemsProvider: { [weak prefs] in prefs?.historyMaxItems ?? PreferencesDefaults.historyMaxItems },
            historyMaxDaysProvider:  { [weak prefs] in prefs?.historyMaxDays  ?? PreferencesDefaults.historyMaxDays },
            llmModelNameProvider: { [weak prefs] kind in
                switch kind {
                case .openai: return prefs?.openAIModel
                case .ollama: return prefs?.ollamaModel
                case .none:   return nil
                }
            },
            whisperModelNameProvider: {
                transcriberRef.current.loadedModelName ?? "<unknown>"
            },
            languageProvider: { [weak prefs] in
                (prefs?.transcriptionLanguage ?? PreferencesDefaults.transcriptionLanguage).whisperCode
            },
            initialPromptProvider: { [weak prefs] in
                guard let prefs, !prefs.technicalVocabulary.isEmpty else { return nil }
                return InitialPromptBuilder.build(vocab: prefs.technicalVocabulary)
            }
        )

        // Sparkle: checagem automática no launch + a cada SUScheduledCheckInterval
        // (24h), e o item "Buscar atualizações…" do menu para checar na hora
        // (revisão de 2026-09-25 da decisão nº 3 da Fase 3).
        // Inicializado aqui (antes do reassign de swapCoordinator com [weak self])
        // pra que todas as stored properties estejam atribuídas antes de qualquer
        // closure capturar `self`.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updates = CheckForUpdatesModel(updater: updaterController.updater)

        // T9: instala o coordinator real, com swapActive que troca o ponteiro
        // `self.transcriber` em runtime. Substitui o stub criado acima. Coordinator
        // é @MainActor — serializa essa troca em relação às chamadas de
        // `transcribe()` que vêm do pipeline (que rodam na main actor via wiring).
        self.swapCoordinator = WhisperModelSwapCoordinator(
            initialActive: prefs.whisperModelName,
            stagingFactory: { WhisperKitTranscriber() },
            swapActive: { [weak self] newActive in
                guard let self else { return newActive }
                let old = self.transcriber
                self.transcriber = newActive
                transcriberRef.current = newActive
                // Persistir aqui, e não na view: o `TranscriptionView` fazia
                // isso dentro de um `if` que dependia do estado **da view**, e
                // navegar para outra seção no meio do swap destruía a view — o
                // swap terminava e ninguém persistia, então o launch seguinte
                // carregava o modelo antigo em silêncio (auditoria §5.3).
                if let name = newActive.loadedModelName {
                    self.prefs.whisperModelName = name
                }
                Diag.notice(.app, "transcriber swapped (old=\(old.loadedModelName ?? "nil") → new=\(newActive.loadedModelName ?? "nil"))")
                return old
            }
        )

        wireHotkeyToPipeline()
        wirePipelineToAppState()
        wirePermissionsToAppState()
        wireHealthCheckerInvalidation(prefs: prefs, healthChecker: healthChecker)
        // NOTE: fire-and-forget. Se o user dispara hotkey muito cedo (antes do
        // fetch completar) e o style selecionado for custom, styleProvider
        // não acha o style e cai pra `conversaInformal`. Probabilidade baixa
        // (SwiftData fetch é rápido); aceitar como trade-off pra não bloquear
        // boot atrás de I/O. Resolver com synchronous-reload exigiria quebrar
        // o contrato `async` do protocolo.
        Task { await customStyleStore.reload() }

        // Quando toast muda (show/dismiss/auto-dismiss), re-render do panel
        // — garante que o toast aparece (e some) mesmo quando o pipeline
        // está em .idle.
        toastCenter.$current
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.refreshIndicator(for: self.appState.pipeline) }
            }
            .store(in: &cancellables)

        if !showOnboarding {
            ensureMicPermission()
            startHotkeyServiceLogging()
            requestAccessibilityIfMissing()
            loadModelLogging(prefs.whisperModelName)
        }
    }

    /// Das três permissões, a Acessibilidade era a única que o app nunca
    /// pedia: só consultava, e o usuário descobria que faltava quando o
    /// primeiro ditado não colava (relato de campo, 2026-09-25). O pedido
    /// mostra o diálogo do macOS e põe o app na lista dos Ajustes. O atraso
    /// curto evita que ele apareça no mesmo instante do pedido de microfone.
    private func requestAccessibilityIfMissing() {
        guard permissions.snapshot().accessibility != .granted else { return }
        let permissions = self.permissions
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard permissions.snapshot().accessibility != .granted else { return }
            permissions.requestAccessibility()
        }
    }

    private func wireHealthCheckerInvalidation(prefs: PreferencesStore, healthChecker: OllamaHealthChecker) {
        prefs.$refinerKind.dropFirst().sink { _ in
            Task { await healthChecker.invalidate() }
        }.store(in: &cancellables)
        prefs.$ollamaBaseURL.dropFirst().sink { _ in
            Task { await healthChecker.invalidate() }
        }.store(in: &cancellables)
    }

    private func ensureMicPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        Diag.info(.permissions, "mic status=\(status.rawValue) video status=\(videoStatus.rawValue) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)")
        guard status != .authorized else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Diag.info(.permissions, "activationPolicy promoted to .regular pra prompt")

        Task {
            // Tentativa 0: video. C920 é camera+mic combinado; em macOS 26
            // o device pode exigir Camera grant pra liberar o audio também.
            let okVideo = await AVCaptureDevice.requestAccess(for: .video)
            Diag.info(.permissions, "video requestAccess -> \(okVideo)")

            // Tentativa 1: audio
            let ok1 = await AVCaptureDevice.requestAccess(for: .audio)
            Diag.info(.permissions, "mic requestAccess -> \(ok1)")

            if !ok1 {
                // Tentativa 2: AVCaptureSession real, que é o caminho canônico
                Diag.info(.permissions, "tentando via AVCaptureSession")
                let session = AVCaptureSession()
                if let dev = AVCaptureDevice.default(for: .audio) {
                    do {
                        let input = try AVCaptureDeviceInput(device: dev)
                        if session.canAddInput(input) {
                            session.addInput(input)
                            session.startRunning()
                            Diag.info(.permissions, "capture session running — popup deveria ter aparecido")
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            session.stopRunning()
                        }
                    } catch {
                        Diag.error(.permissions, "AVCaptureDeviceInput falhou: \(String(describing: error))")
                    }
                } else {
                    Diag.error(.permissions, "AVCaptureDevice.default(.audio) retornou nil")
                }
            }

            await MainActor.run {
                NSApp.setActivationPolicy(.accessory)
                Diag.info(.permissions, "activationPolicy back to .accessory")
            }
        }
    }

    /// Fecha o menu e ativa o app antes de chamar o Sparkle: num app de barra
    /// de menu, a janela dele pode abrir atrás de tudo — o mesmo cuidado que as
    /// Preferências já tomam.
    @MainActor
    func checkForUpdates() {
        PreferencesWindow.dismissMenuBarExtraPopover()
        NSApp.activate(ignoringOtherApps: true)
        Diag.notice(.app, "checagem de atualização pedida pelo menu")
        updates.checkForUpdates()
    }

    /// `section` abre a janela direto numa seção — o aviso "permissões
    /// pendentes" do menu usa isso para cair em Permissões.
    @MainActor
    func openPreferences(section: PrefsSection? = nil) {
        if let section { preferencesNavigator.selection = section }
        let view = PreferencesRoot(
            prefs: prefs,
            customStore: customStyleStore,
            ollamaModelLister: { [weak self] in
                OllamaModelLister(
                    session: .shared,
                    baseURL: URL(string: self?.prefs.ollamaBaseURL ?? "")
                        ?? URL(string: "http://localhost:11434")!)
            },
            openAIKeyEditor: { [weak self] in self?.keyPromptWindow.show(onCancel: {}, onSaved: {}) },
            healthChecker: healthChecker,
            indicatorPanel: indicatorPanel,
            keychain: keychain,
            historyStore: historyStore,
            injector: injector,
            swapCoordinator: swapCoordinator,
            modelStore: modelStore,
            navigator: preferencesNavigator,
            permissions: permissions,
            health: health,
            loadedModelName: { [weak self] in self?.transcriber.loadedModelName },
            modelDownloaded: { [weak self] in
                guard let self else { return nil }
                return self.modelStore.isDownloaded(self.prefs.whisperModelName)
            })
        preferencesWindow.show(content: { AnyView(view) })
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        showOnboarding = false
        startHotkeyServiceLogging()
        // Onboarding já chama loadModel via OnboardingCoordinator;
        // mas se algo deu errado lá (ex: usuário pulou o passo), garantimos
        // que tenta de novo aqui se ainda não está carregado.
        if transcriber.loadedModelName == nil {
            loadModelLogging(prefs.whisperModelName)
        }
    }

    private func loadModelLogging(_ name: String) {
        let transcriber = self.transcriber
        Task { @MainActor [weak self] in
            self?.appState.whisperModelReady = false
            let started = ContinuousClock.now
            Diag.info(.transcribe, "loadModel('\(name)') iniciando")
            do {
                try await transcriber.loadModel(name) { p in
                    Diag.info(.transcribe, "download \(Int(p * 100))%")
                }
                let elapsed = started.duration(to: .now)
                let seconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18
                self?.appState.whisperModelReady = true
                // O tempo importa: num primeiro launch após upgrade de macOS o
                // CoreML recompila o modelo para a ANE e isso passa de 90 s,
                // contra ~13 s num launch normal. Sem o número no log, a
                // diferença entre "lento" e "quebrado" é invisível.
                Diag.notice(.transcribe, "modelo '\(name)' carregado em \(String(format: "%.1f", seconds))s")
            } catch {
                self?.appState.whisperModelReady = false
                Diag.error(.transcribe, "loadModel FALHOU: \(String(describing: error))")
            }
        }
    }

    private func startHotkeyServiceLogging() {
        do {
            try hotkeyService.start()
            Diag.notice(.hotkey, "hotkey service started")
        } catch {
            Diag.error(.hotkey, "hotkey service falhou ao iniciar: \(String(describing: error))")
        }
    }

    private func wireHotkeyToPipeline() {
        let stream = hotkeyService.events
        let pipeline = self.pipeline
        let coord = self.swapCoordinator
        Task {
            for await event in stream {
                Diag.info(.hotkey, "hotkey event recebido: \(String(describing: event))")
                if case .swapping = await coord.state {
                    Diag.info(.hotkey, "hotkey ignored: swap in progress")
                    continue
                }
                let pipelineEvent: PipelineEvent = (event == .toggle) ? .toggle : .cancel
                await pipeline.handle(pipelineEvent)
            }
        }
    }

    private func wirePipelineToAppState() {
        let stream = pipeline.events
        Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await MainActor.run {
                    switch event {
                    case .stateChanged(let s):
                        self.appState.pipeline = s
                        self.health.noteState(s)
                        self.refreshIndicator(for: s)
                    case .errorOccurred(let msg):
                        Diag.error(.pipeline, "pipeline error: \(msg)")
                    case .finished:
                        self.health.noteSuccess()
                    case .refinerFellBack(let reason):
                        self.toastCenter.show(Toast(kind: .refinerFellBack(reason: reason)))
                    case .injectionFailed:
                        self.health.noteInjectionFailure()
                        self.toastCenter.show(Toast(kind: .injectionFailed))
                    case .historySaveFailed:
                        self.toastCenter.show(Toast(kind: .historySaveFailed))
                    case .permissionDenied(let kind):
                        self.toastCenter.show(Toast(kind: .permissionDenied(kind: kind)))
                    case .captureFailed(let reason):
                        // Os dois motivos entram em "curtos": a captura não
                        // rendeu áudio utilizável. O log distingue qual foi.
                        self.health.noteDiscardedShort()
                        Diag.error(.pipeline, "captureFailed(\(reason))")
                        self.toastCenter.show(Toast(kind: .captureFailed))
                    case .emptyTranscription:
                        self.health.noteEmptyTranscription()
                        self.toastCenter.show(Toast(kind: .emptyTranscription))
                    case .transcriberRecoveryRequested:
                        self.recoverTranscriber()
                    case .transcriberRecovered:
                        self.health.noteRecovery()
                        self.toastCenter.show(Toast(kind: .transcriberRecovered))
                    case .transcriberNotReady:
                        self.toastCenter.show(Toast(kind: .transcriberNotReady))
                    case .toggle, .cancel:
                        break
                    }
                }
            }
        }
    }

    /// Recria o reconhecedor depois de dois vazios seguidos — a hipótese H2 da
    /// auditoria é que o decoder degrada ao longo de uma sessão longa, e não há
    /// métrica que distinga isso de "o usuário não falou".
    ///
    /// Usa `reload()`, que relê **do disco** — sem rede, e portanto sem depender
    /// de `huggingface.co` estar de pé no momento em que o app está degradado.
    private func recoverTranscriber() {
        guard !isRecoveringTranscriber else {
            Diag.info(.transcribe, "recuperação já em andamento — ignorando pedido")
            return
        }
        isRecoveringTranscriber = true
        let transcriber = self.transcriber
        let pipeline = self.pipeline
        Task { @MainActor [weak self] in
            defer { self?.isRecoveringTranscriber = false }
            do {
                try await transcriber.reload()
                await pipeline.noteTranscriberRecovered()
            } catch {
                Diag.error(.transcribe, "recriar o transcriber falhou: \(String(describing: error))")
            }
        }
    }

    private func wirePermissionsToAppState() {
        let stream = permissions.makeSnapshots()
        Task { [weak self] in
            var lastAttempt: ContinuousClock.Instant?
            for await snap in stream {
                guard let self else { return }
                // Input Monitoring concedido e nenhum tap vivo: a hotkey está
                // morta (S4 da auditoria §3.4) — sobe de novo. `start()` é
                // idempotente.
                //
                // Checagem por ESTADO, não por transição. A versão por
                // transição partia de `previous == nil`, então o primeiro
                // snapshot de todo launch contava como "voltou a granted" e
                // reiniciava o tap à toa — e foi essa linha, lida no log em
                // campo, que fez parecer validado um re-start ao vivo que não
                // tinha acontecido. De bônus, cobre qualquer outro motivo de
                // tap morto com a permissão em dia. Tentativas a cada 10 s no
                // máximo, para uma falha persistente não inundar o log.
                let tapMissing = await MainActor.run {
                    snap.inputMonitoring == .granted && !self.hotkeyService.isTapEnabled
                }
                let throttled = lastAttempt.map { $0.duration(to: .now) < .seconds(10) } ?? false
                if tapMissing, !throttled {
                    lastAttempt = .now
                    await MainActor.run {
                        Diag.notice(.hotkey, "Input Monitoring concedido e nenhum tap ativo — iniciando a hotkey")
                        do { try self.hotkeyService.start() }
                        catch { Diag.error(.hotkey, "start falhou: \(String(describing: error))") }
                    }
                }
                await MainActor.run {
                    self.appState.permissionsAllGranted = snap.allGranted
                }
            }
        }
    }

    private func refreshIndicator(for state: PipelineState) {
        // Visibility rule: state != .idle OU toast pendente → visible.
        // Quando state vai pra .idle mas há toast: panel fica visível
        // mostrando só o toast até auto-dismiss (4s).
        let toast = toastCenter.current
        if case .idle = state, toast == nil {
            indicatorPanel.hide()
            return
        }
        let pipelineRef = self.pipeline
        let toastCenterRef = self.toastCenter
        indicatorPanel.show(
            state: state,
            variant: prefs.indicatorVariant,
            toast: toast,
            onCancel: { Task { await pipelineRef.handle(.cancel) } },
            onToastDismiss: { toastCenterRef.dismiss() })
    }
}

/// Holder mutável compartilhado entre AppContainer e PipelineCoordinator.
/// Necessário porque PipelineCoordinator é construído DURANTE o init do
/// AppContainer (antes de `self` poder ser capturado em closures), mas precisa
/// resolver a referência atual do transcriber em runtime — que pode mudar
/// depois de um swap. Acessado apenas na MainActor.
@MainActor
final class TranscriberRef {
    var current: Transcribing
    init(_ initial: Transcribing) { self.current = initial }
}
