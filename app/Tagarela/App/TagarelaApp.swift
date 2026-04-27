import SwiftUI

@main
struct TagarelaApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(container.appState)
        } label: {
            Label {
                Text("tagarela")
            } icon: {
                Glyph(size: 16, color: .primary,
                      recording: container.appState.pipeline != .idle)
            }
        }
        .menuBarExtraStyle(.window)

        WindowGroup("tagarela — bem-vindo", id: "onboarding") {
            if container.showOnboarding {
                OnboardingWindow(onFinish: { container.finishOnboarding() })
                    .environmentObject(container.onboarding)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 560)
    }
}
