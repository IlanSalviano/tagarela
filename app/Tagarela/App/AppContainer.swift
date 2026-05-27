import SwiftUI
import AppKit
import AVFoundation
import Combine
import OSLog
import SwiftData
import Sparkle

@MainActor
final class AppContainer: ObservableObject {
    let appState = AppState()
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
                    Logger.tagarela.notice("migration: preserved existing model on disk: \(candidate, privacy: .public)")
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

        // Sparkle minimal: auto-check no launch + a cada SUScheduledCheckInterval (24h).
        // Sheet nativa de update aparece quando feed lista versão > atual.
        // Sem UI manual de "Verificar atualizações" nesta fase.
        // Inicializado aqui (antes do reassign de swapCoordinator com [weak self])
        // pra que todas as stored properties estejam atribuídas antes de qualquer
        // closure capturar `self`.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

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
                Logger.tagarela.notice("AppContainer.transcriber swapped (old=\(old.loadedModelName ?? "nil", privacy: .public) → new=\(newActive.loadedModelName ?? "nil", privacy: .public))")
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
            loadModelLogging(prefs.whisperModelName)
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
        Logger.tagarela.info("mic status=\(status.rawValue, privacy: .public) video status=\(videoStatus.rawValue, privacy: .public) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)")
        guard status != .authorized else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Logger.tagarela.info("activationPolicy promoted to .regular pra prompt")

        Task {
            // Tentativa 0: video. C920 é camera+mic combinado; em macOS 26
            // o device pode exigir Camera grant pra liberar o audio também.
            let okVideo = await AVCaptureDevice.requestAccess(for: .video)
            Logger.tagarela.info("video requestAccess -> \(okVideo, privacy: .public)")

            // Tentativa 1: audio
            let ok1 = await AVCaptureDevice.requestAccess(for: .audio)
            Logger.tagarela.info("mic requestAccess -> \(ok1, privacy: .public)")

            if !ok1 {
                // Tentativa 2: AVCaptureSession real, que é o caminho canônico
                Logger.tagarela.info("tentando via AVCaptureSession")
                let session = AVCaptureSession()
                if let dev = AVCaptureDevice.default(for: .audio) {
                    do {
                        let input = try AVCaptureDeviceInput(device: dev)
                        if session.canAddInput(input) {
                            session.addInput(input)
                            session.startRunning()
                            Logger.tagarela.info("capture session running — popup deveria ter aparecido")
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            session.stopRunning()
                        }
                    } catch {
                        Logger.tagarela.error("AVCaptureDeviceInput falhou: \(String(describing: error), privacy: .public)")
                    }
                } else {
                    Logger.tagarela.error("AVCaptureDevice.default(.audio) retornou nil")
                }
            }

            await MainActor.run {
                NSApp.setActivationPolicy(.accessory)
                Logger.tagarela.info("activationPolicy back to .accessory")
            }
        }
    }

    @MainActor
    func openPreferences() {
        let view = PreferencesRoot(
            prefs: prefs,
            customStore: customStyleStore,
            ollamaModelLister: { [weak self] in
                OllamaModelLister(
                    session: .shared,
                    baseURL: URL(string: self?.prefs.ollamaBaseURL ?? "")
                        ?? URL(string: "http://localhost:11434")!)
            },
            openAIKeyEditor: { [weak self] in self?.keyPromptWindow.show() },
            healthChecker: healthChecker,
            indicatorPanel: indicatorPanel,
            keychain: keychain,
            historyStore: historyStore,
            injector: injector,
            swapCoordinator: swapCoordinator,
            modelStore: modelStore)
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
        Task {
            Logger.tagarela.info("loadModel('\(name, privacy: .public)') iniciando")
            do {
                try await transcriber.loadModel(name) { p in
                    Logger.tagarela.info("download \(Int(p * 100), privacy: .public)%")
                }
                Logger.tagarela.info("modelo '\(name, privacy: .public)' carregado")
            } catch {
                Logger.tagarela.error("loadModel FALHOU: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func startHotkeyServiceLogging() {
        do {
            try hotkeyService.start()
            Logger.tagarela.info("hotkey service started")
        } catch {
            Logger.tagarela.error("hotkey service falhou ao iniciar: \(String(describing: error), privacy: .public)")
        }
    }

    private func wireHotkeyToPipeline() {
        let stream = hotkeyService.events
        let pipeline = self.pipeline
        let coord = self.swapCoordinator
        Task {
            for await event in stream {
                Logger.tagarela.info("hotkey event recebido: \(String(describing: event), privacy: .public)")
                if case .swapping = await coord.state {
                    Logger.tagarela.info("hotkey ignored: swap in progress")
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
                        self.refreshIndicator(for: s)
                    case .errorOccurred(let msg):
                        Logger.tagarela.error("pipeline error: \(msg, privacy: .public)")
                    case .finished:
                        break
                    case .refinerFellBack(let reason):
                        self.toastCenter.show(Toast(kind: .refinerFellBack(reason: reason)))
                    case .injectionFailed:
                        self.toastCenter.show(Toast(kind: .injectionFailed))
                    case .historySaveFailed:
                        self.toastCenter.show(Toast(kind: .historySaveFailed))
                    case .permissionDenied(let kind):
                        self.toastCenter.show(Toast(kind: .permissionDenied(kind: kind)))
                    case .toggle, .cancel:
                        break
                    }
                }
            }
        }
    }

    private func wirePermissionsToAppState() {
        let stream = permissions.snapshots
        Task { [weak self] in
            for await snap in stream {
                guard let self else { return }
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

extension Logger {
    static let tagarela = Logger(subsystem: "com.tagarela", category: "App")
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
