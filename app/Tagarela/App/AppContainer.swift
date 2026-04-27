import SwiftUI
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
            try? hotkeyService.start()
            Task { try? await transcriber.loadModel("large-v3") { _ in } }
        }
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        showOnboarding = false
        try? hotkeyService.start()
    }

    private func wireHotkeyToPipeline() {
        let stream = hotkeyService.events
        let pipeline = self.pipeline
        Task {
            for await event in stream {
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
