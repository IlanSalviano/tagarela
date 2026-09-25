import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var prefs: PreferencesStore
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var health: PipelineHealth
    @ObservedObject var updates: CheckForUpdatesModel
    let customStore: CustomStyleStoreLive?  // nil quando container falha
    let styleProvider: StyleProvider
    let recentsProvider: RecentTranscriptionsProvider
    let injector: Injecting
    var onSelectOpenAINeedsKey: (RefinerKind) -> Void = { _ in }
    var onExplicitConfigureKey: () -> Void = {}
    var onOpenPreferences: () -> Void = {}
    var onOpenPermissions: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}
    /// Modelo Whisper carregado agora — resolvido em runtime porque muda com o swap.
    var loadedModelName: () -> String? = { nil }
    /// Onboarding fechado no ⌘W sem concluir deixava o app "zumbi": a hotkey e
    /// o modelo nunca subiam e não havia como reabrir a janela (auditoria §5.3).
    var onboardingPending: Bool = false

    private var refinerLabel: String {
        switch prefs.refinerKind {
        case .ollama: return "ollama · \(prefs.ollamaModel)"
        case .openai: return "openai · \(prefs.openAIModel)"
        case .none:   return String(localized: "pipeline.sub.refining.none",
                                    defaultValue: "sem refinador")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Wordmark(size: 18)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(DS.Font.mono(9))
                    .tracking(0.5)
                    .foregroundStyle(DS.Color.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(Divider().background(DS.Color.hairline), alignment: .bottom)

            StateRow(state: appState.pipeline,
                     health: health,
                     loadedModelName: loadedModelName(),
                     refinerLabel: refinerLabel,
                     permissionsPending: !appState.permissionsAllGranted,
                     onResolvePermissions: onOpenPermissions,
                     modelLoading: !appState.whisperModelReady)

            Divider().background(DS.Color.hairline)

            BackendSubmenu(prefs: prefs,
                           onSelectOpenAINeedsKey: onSelectOpenAINeedsKey,
                           onExplicitConfigureKey: onExplicitConfigureKey)

            if let customStore {
                StyleSubmenu(prefs: prefs, customStore: customStore, styleProvider: styleProvider)
            } else {
                // Fallback: sem reactivity (custom styles offline) — só built-ins
                StyleSubmenuStaticFallback(prefs: prefs, styleProvider: styleProvider)
            }

            Divider().background(DS.Color.hairline)

            RecentTranscriptionsSubmenu(provider: recentsProvider,
                                         injector: injector)

            if onboardingPending {
                Button(action: {
                    openWindow(id: "onboarding")
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    HStack {
                        Text(String(localized: "menubar.onboarding.resume",
                                    defaultValue: "Concluir configuração…"))
                            .font(DS.Font.mono(11))
                            .foregroundStyle(DS.Color.carmine)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(action: onOpenPreferences) {
                HStack {
                    Text(NSLocalizedString("menubar.preferences", value: "Preferências…", comment: ""))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onCheckForUpdates) {
                HStack {
                    Text(String(localized: "menubar.checkForUpdates",
                                defaultValue: "Buscar atualizações…"))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Desabilitado enquanto o Sparkle já está checando.
            .disabled(!updates.canCheckForUpdates)
            .opacity(updates.canCheckForUpdates ? 1 : 0.4)

            Divider().background(DS.Color.hairline)
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Text(NSLocalizedString("menubar.quit", value: "sair", comment: ""))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 320)
        .background(DS.Color.paper)
    }
}
