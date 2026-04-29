import SwiftUI

struct PreferencesRoot: View {
    @ObservedObject var prefs: PreferencesStore
    let customStore: CustomStyleStore
    let ollamaModelLister: () -> OllamaModelLister
    let openAIKeyEditor: () -> Void
    let healthChecker: OllamaHealthChecker
    let indicatorPanel: FloatingIndicatorPanel
    let keychain: KeychainService
    let historyStore: HistoryStore
    let injector: Injecting

    @State private var selection: PrefsSection = .geral

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: PrefsSection.geral) { Label(PrefsSection.geral.label, systemImage: "gearshape") }

                Section(header: Text(String(localized: "preferences.section.refiner.group", defaultValue: "Refiner"))) {
                    NavigationLink(value: PrefsSection.refinerGeral) { Text(PrefsSection.refinerGeral.label) }
                    NavigationLink(value: PrefsSection.refinerOllama) { Text(PrefsSection.refinerOllama.label) }
                    NavigationLink(value: PrefsSection.refinerOpenAI) { Text(PrefsSection.refinerOpenAI.label) }
                }

                NavigationLink(value: PrefsSection.estilos) { Label(PrefsSection.estilos.label, systemImage: "sparkles") }
                NavigationLink(value: PrefsSection.audio) { Label(PrefsSection.audio.label, systemImage: "waveform") }
                NavigationLink(value: PrefsSection.historico) { Label(PrefsSection.historico.label, systemImage: "scroll") }
                NavigationLink(value: PrefsSection.vocabulario) { Label(PrefsSection.vocabulario.label, systemImage: "book") }
                NavigationLink(value: PrefsSection.atalhos) { Label(PrefsSection.atalhos.label, systemImage: "keyboard") }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selection {
            case .geral:         GeneralView(prefs: prefs, indicatorPanel: indicatorPanel)
            case .refinerGeral:  RefinerGeneralView(prefs: prefs)
            case .refinerOllama: RefinerOllamaView(prefs: prefs, modelLister: ollamaModelLister)
            case .refinerOpenAI: RefinerOpenAIView(prefs: prefs, keychain: keychain, openAIKeyEditor: openAIKeyEditor)
            case .estilos:
                    if let live = customStore as? CustomStyleStoreLive {
                        StylesView(prefs: prefs, customStore: live)
                    } else {
                        Text(String(localized: "styles.unavailable",
                                     defaultValue: "Custom styles indisponíveis (armazenamento offline)"))
                            .padding()
                    }
            case .audio:         AudioView(prefs: prefs)
            case .historico:     HistoryView(prefs: prefs, historyStore: historyStore, injector: injector)
            case .vocabulario:   VocabularyView(prefs: prefs)
            case .atalhos:       ShortcutsView(prefs: prefs)
            }
        }
        .frame(minWidth: 600, idealWidth: 720, minHeight: 400, idealHeight: 520)
    }
}
