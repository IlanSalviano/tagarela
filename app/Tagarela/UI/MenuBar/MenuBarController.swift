import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var prefs: PreferencesStore
    @ObservedObject var health: PipelineHealth
    let customStore: CustomStyleStoreLive?  // nil quando container falha
    let styleProvider: StyleProvider
    let recentsProvider: RecentTranscriptionsProvider
    let injector: Injecting
    var onSelectOpenAINeedsKey: (RefinerKind) -> Void = { _ in }
    var onExplicitConfigureKey: () -> Void = {}
    var onOpenPreferences: () -> Void = {}
    /// Modelo Whisper carregado agora — resolvido em runtime porque muda com o swap.
    var loadedModelName: () -> String? = { nil }

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
                     refinerLabel: refinerLabel)

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
