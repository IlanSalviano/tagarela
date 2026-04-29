import SwiftUI
import AppKit
import AVFoundation
import Combine
import OSLog

@MainActor
final class AppContainer: ObservableObject {
    let appState = AppState()
    let permissions: PermissionService
    let transcriber: Transcribing
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
    let keyPromptWindow: OpenAIKeyPromptWindow
    private var cancellables: Set<AnyCancellable> = []

    @Published var showOnboarding: Bool

    init() {
        let permissions = PermissionServiceLive()
        let transcriber = WhisperKitTranscriber()
        let injector = InjectorLive()
        let hotkeyService = HotkeyServiceLive()

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
        // weak prefs: defesa contra deallocação prematura. Na prática, AppContainer
        // vive durante toda a vida do app, então fatalError aqui é inalcançável.
        let factory = RefinerFactory(
            prefs: prefs,
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

        let historyStore: HistoryStore = (try? HistoryStoreLive()) ?? HistoryStoreNoop()

        let keyPromptWindow = OpenAIKeyPromptWindow(keychain: keychain)

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
        self.keyPromptWindow = keyPromptWindow
        self.pipeline = PipelineCoordinator(
            audio: audio,
            transcriber: transcriber,
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
            whisperModelNameProvider: { [weak transcriber] in
                transcriber?.loadedModelName ?? "<unknown>"
            },
            initialPromptProvider: { [weak prefs] in
                guard let prefs, !prefs.technicalVocabulary.isEmpty else { return nil }
                return InitialPromptBuilder.build(vocab: prefs.technicalVocabulary)
            }
        )
        self.onboarding = OnboardingCoordinator(
            permissionService: permissions, transcriber: transcriber
        )
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingCompleted")

        wireHotkeyToPipeline()
        wirePipelineToAppState()
        wirePermissionsToAppState()
        wireHealthCheckerInvalidation(prefs: prefs, healthChecker: healthChecker)

        if !showOnboarding {
            ensureMicPermission()
            startHotkeyServiceLogging()
            loadModelLogging("large-v3")
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

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        showOnboarding = false
        startHotkeyServiceLogging()
        // Onboarding já chama loadModel via OnboardingCoordinator;
        // mas se algo deu errado lá (ex: usuário pulou o passo), garantimos
        // que tenta de novo aqui se ainda não está carregado.
        if transcriber.loadedModelName == nil {
            loadModelLogging("large-v3")
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
        Task {
            for await event in stream {
                Logger.tagarela.info("hotkey event recebido: \(String(describing: event), privacy: .public)")
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
                    default: break
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
        switch state {
        case .idle:
            indicatorPanel.hide()
        default:
            let pipelineRef = self.pipeline
            indicatorPanel.show(rootView:
                IndicatorPill(state: state) {
                    Task { await pipelineRef.handle(.cancel) }
                }
            )
        }
    }
}

extension Logger {
    static let tagarela = Logger(subsystem: "com.tagarela", category: "App")
}
