import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
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
                    downloadProgress: coordinator.modelDownloadProgress,
                    loaded: coordinator.modelLoaded,
                    onStart: { onFinish() }
                )
                .onAppear { coordinator.loadModel("large-v3") }
            }
        }
    }
}
