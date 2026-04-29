import SwiftUI

struct RefinerGeneralView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.refiner.geral.backend", defaultValue: "Backend"))) {
                Picker("", selection: $prefs.refinerKind) {
                    Text(String(localized: "refiner.kind.ollama", defaultValue: "Ollama")).tag(RefinerKind.ollama)
                    Text(String(localized: "refiner.kind.openai", defaultValue: "OpenAI")).tag(RefinerKind.openai)
                    Text(String(localized: "refiner.kind.none", defaultValue: "Sem LLM")).tag(RefinerKind.none)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            Section(header: Text(String(localized: "preferences.refiner.geral.timeout.header", defaultValue: "Timeout"))) {
                LabeledContent(String(localized: "preferences.refiner.geral.timeout.label", defaultValue: "Tempo máximo (s)")) {
                    TextField("", value: $prefs.refinerTimeoutSec, format: .number)
                        .frame(width: 80).multilineTextAlignment(.trailing)
                }
                Text(String(localized: "preferences.refiner.geral.timeout.help",
                             defaultValue: "Aplicado a OpenAI e Ollama. Padrão: 60s. Modelos lentos podem precisar de mais."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
