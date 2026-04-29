import SwiftUI

@MainActor
struct RefinerOpenAIView: View {
    @ObservedObject var prefs: PreferencesStore
    let keychain: KeychainService
    let openAIKeyEditor: () -> Void

    @State private var keyMaskedDisplay: String = "—"

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.refiner.openai.provider.header", defaultValue: "Provider"))) {
                Picker("", selection: $prefs.openAIEndpoint.provider) {
                    Text(String(localized: "preferences.refiner.openai.provider.official",
                                 defaultValue: "OpenAI oficial")).tag(OpenAIProvider.official)
                    Text(String(localized: "preferences.refiner.openai.provider.openrouter",
                                 defaultValue: "OpenRouter")).tag(OpenAIProvider.openrouter)
                    Text(String(localized: "preferences.refiner.openai.provider.lmstudio",
                                 defaultValue: "LM Studio")).tag(OpenAIProvider.lmstudio)
                    Text(String(localized: "preferences.refiner.openai.provider.custom",
                                 defaultValue: "URL custom")).tag(OpenAIProvider.custom)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: prefs.openAIEndpoint.provider) { _, newProvider in
                    if let url = OpenAIEndpointDefaults.defaultURL(for: newProvider) {
                        prefs.openAIEndpoint = OpenAIEndpoint(provider: newProvider, baseURL: url)
                    }
                }
            }
            Section(header: Text(String(localized: "preferences.refiner.openai.url.header", defaultValue: "Base URL"))) {
                TextField("", text: Binding(
                    get: { prefs.openAIEndpoint.baseURL.absoluteString },
                    set: { newStr in
                        if let url = URL(string: newStr) {
                            prefs.openAIEndpoint = OpenAIEndpoint(
                                provider: prefs.openAIEndpoint.provider,
                                baseURL: url)
                        }
                    }))
                    .frame(maxWidth: 380)
                    .textFieldStyle(.roundedBorder)
            }
            Section(header: Text(String(localized: "preferences.refiner.openai.model.header", defaultValue: "Modelo"))) {
                TextField("", text: $prefs.openAIModel)
                    .frame(maxWidth: 240)
                    .textFieldStyle(.roundedBorder)
            }
            Section(header: Text(String(localized: "preferences.refiner.openai.key.header", defaultValue: "API key"))) {
                HStack {
                    Text(keyMaskedDisplay).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(String(localized: "preferences.refiner.openai.key.edit", defaultValue: "Alterar…")) {
                        openAIKeyEditor()
                        // refresh display após o modal fechar (best effort)
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            refreshKeyDisplay()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { refreshKeyDisplay() }
    }

    private func refreshKeyDisplay() {
        if let key = try? keychain.openAIKey(), !key.isEmpty {
            let last4 = String(key.suffix(4))
            keyMaskedDisplay = "••••••••\(last4)"
        } else {
            keyMaskedDisplay = String(localized: "preferences.refiner.openai.key.missing",
                                       defaultValue: "Não configurada")
        }
    }
}
