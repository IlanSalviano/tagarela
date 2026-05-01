import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @Environment(\.dismissWindow) private var dismissWindow
    var onFinish: () -> Void

    var body: some View {
        Group {
            switch coordinator.step {
            case .welcome:
                OnboardWelcome(onContinue: { coordinator.advance() })
            case .perms:
                OnboardPerms(
                    snapshot: coordinator.permsSnapshot,
                    onMicTap: {
                        Task { _ = await coordinator.permissionService.requestMicrophone() }
                    },
                    onAccessibilityTap: { coordinator.permissionService.openAccessibilitySettings() },
                    onInputMonitoringTap: { coordinator.permissionService.openInputMonitoringSettings() },
                    onContinue: { coordinator.advance() },
                    onBack: { coordinator.back() }
                )
            case .model:
                OnboardModel(
                    selected: $coordinator.selectedModel,
                    downloadProgress: coordinator.modelDownloadProgress,
                    loaded: coordinator.modelLoaded,
                    errorMessage: coordinator.modelLoadError,
                    onRetry: { coordinator.loadSelectedModel() },
                    onStart: {
                        onFinish()
                        dismissWindow(id: "onboarding")
                    }
                )
                .onAppear { coordinator.loadSelectedModel() }
                .onChange(of: coordinator.selectedModel) { _, _ in
                    coordinator.loadSelectedModel()
                }
            }
        }
    }
}
