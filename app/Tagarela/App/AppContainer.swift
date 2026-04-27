import SwiftUI
import AVFoundation
import OSLog

@MainActor
final class AppContainer: ObservableObject {
    let appState = AppState()
    let permissions: PermissionService
    let transcriber: Transcribing
    let audio: AudioCapturing
    let injector: Injecting
    let refiner: TextRefiner
    let hotkeyService: HotkeyService
    let pipeline: PipelineCoordinator
    let onboarding: OnboardingCoordinator
    let indicatorPanel = FloatingIndicatorPanel()

    @Published var showOnboarding: Bool

    init() {
        let permissions = PermissionServiceLive()
        let transcriber = WhisperKitTranscriber()
        let audio = AudioCaptureLive()
        let injector = InjectorLive()
        let refiner = IdentityRefiner()
        let hotkeyService = HotkeyServiceLive()

        self.permissions = permissions
        self.transcriber = transcriber
        self.audio = audio
        self.injector = injector
        self.refiner = refiner
        self.hotkeyService = hotkeyService
        self.pipeline = PipelineCoordinator(
            audio: audio, transcriber: transcriber,
            refiner: refiner, injector: injector
        )
        self.onboarding = OnboardingCoordinator(
            permissionService: permissions, transcriber: transcriber
        )
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingCompleted")

        wireHotkeyToPipeline()
        wirePipelineToAppState()
        wirePermissionsToAppState()

        if !showOnboarding {
            ensureMicPermission()
            startHotkeyServiceLogging()
            loadModelLogging("large-v3")
        }
    }

    private func ensureMicPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        FileHandle.standardError.write(Data("[app] mic status=\(status.rawValue) video status=\(videoStatus.rawValue) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)\n".utf8))
        guard status != .authorized else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        FileHandle.standardError.write(Data("[app] activationPolicy promoted to .regular pra prompt\n".utf8))

        Task {
            // Tentativa 0: video. C920 é camera+mic combinado; em macOS 26
            // o device pode exigir Camera grant pra liberar o audio também.
            let okVideo = await AVCaptureDevice.requestAccess(for: .video)
            FileHandle.standardError.write(Data("[app] video requestAccess -> \(okVideo)\n".utf8))

            // Tentativa 1: audio
            let ok1 = await AVCaptureDevice.requestAccess(for: .audio)
            FileHandle.standardError.write(Data("[app] mic requestAccess -> \(ok1)\n".utf8))

            if !ok1 {
                // Tentativa 2: AVCaptureSession real, que é o caminho canônico
                FileHandle.standardError.write(Data("[app] tentando via AVCaptureSession\n".utf8))
                let session = AVCaptureSession()
                if let dev = AVCaptureDevice.default(for: .audio) {
                    do {
                        let input = try AVCaptureDeviceInput(device: dev)
                        if session.canAddInput(input) {
                            session.addInput(input)
                            session.startRunning()
                            FileHandle.standardError.write(Data("[app] capture session running — popup deveria ter aparecido\n".utf8))
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            session.stopRunning()
                        }
                    } catch {
                        FileHandle.standardError.write(Data("[app] AVCaptureDeviceInput falhou: \(error)\n".utf8))
                    }
                } else {
                    FileHandle.standardError.write(Data("[app] AVCaptureDevice.default(.audio) retornou nil\n".utf8))
                }
            }

            await MainActor.run {
                NSApp.setActivationPolicy(.accessory)
                FileHandle.standardError.write(Data("[app] activationPolicy back to .accessory\n".utf8))
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
            FileHandle.standardError.write(Data("[app] loadModel('\(name)') iniciando\n".utf8))
            do {
                try await transcriber.loadModel(name) { p in
                    FileHandle.standardError.write(Data("[app] download \(Int(p * 100))%\n".utf8))
                }
                FileHandle.standardError.write(Data("[app] modelo '\(name)' carregado\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("[app] loadModel FALHOU: \(String(describing: error))\n".utf8))
            }
        }
    }

    private func startHotkeyServiceLogging() {
        do {
            try hotkeyService.start()
            FileHandle.standardError.write(Data("[app] hotkey service started OK\n".utf8))
            Logger.tagarela.info("hotkey service started")
        } catch {
            FileHandle.standardError.write(Data("[app] hotkey service FALHOU: \(String(describing: error))\n".utf8))
            Logger.tagarela.error("hotkey service falhou ao iniciar: \(String(describing: error), privacy: .public)")
        }
    }

    private func wireHotkeyToPipeline() {
        let stream = hotkeyService.events
        let pipeline = self.pipeline
        Task {
            for await event in stream {
                FileHandle.standardError.write(Data("[app] hotkey event consumido: \(event)\n".utf8))
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
