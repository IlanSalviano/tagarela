import SwiftUI

@main
struct TagarelaApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                customStore: container.customStyleStoreLive,
                styleProvider: container.styleProvider,
                onSelectOpenAINeedsKey: { [container] previous in
                    Task { @MainActor in
                        let hasKey: Bool
                        do {
                            hasKey = (try container.keychain.openAIKey()).map { !$0.isEmpty } ?? false
                        } catch {
                            hasKey = false
                        }
                        guard !hasKey else { return }
                        container.keyPromptWindow.onCancel = {
                            container.prefs.refinerKind = previous
                        }
                        container.keyPromptWindow.onSaved = {}
                        container.keyPromptWindow.show()
                    }
                },
                onExplicitConfigureKey: { [container] in
                    container.keyPromptWindow.onCancel = {}  // sem rollback no caminho explícito
                    container.keyPromptWindow.onSaved = {}
                    container.keyPromptWindow.show()
                },
                onOpenPreferences: {
                    container.openPreferences()
                })
            .environmentObject(container.appState)
            .environmentObject(container.prefs)
        } label: {
            StatusBarIcon(appState: container.appState,
                          shouldOpenOnboarding: container.showOnboarding)
        }
        .menuBarExtraStyle(.window)

        Window("tagarela — bem-vindo", id: "onboarding") {
            if container.showOnboarding {
                OnboardingWindow(onFinish: { container.finishOnboarding() })
                    .environmentObject(container.onboarding)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 560)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "preferences.menu.item", defaultValue: "Preferências…")) {
                    container.openPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

/// Wrapper do Glyph que abre o onboarding no primeiro `.task` se necessário.
/// Usa @Environment(\.openWindow) — só acessível dentro de uma View.
private struct StatusBarIcon: View {
    @ObservedObject var appState: AppState
    let shouldOpenOnboarding: Bool
    @Environment(\.openWindow) private var openWindow
    @State private var didOpenOnboarding = false

    private var iconName: String {
        appState.pipeline == .idle ? "StatusBarTemplate" : "StatusBarRecording"
    }

    var body: some View {
        Image(iconName)
            .resizable()
            .renderingMode(appState.pipeline == .idle ? .template : .original)
            .scaledToFit()
            .frame(width: 18, height: 18)
            .task {
                guard !didOpenOnboarding else { return }
                didOpenOnboarding = true
                if shouldOpenOnboarding {
                    openWindow(id: "onboarding")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}
