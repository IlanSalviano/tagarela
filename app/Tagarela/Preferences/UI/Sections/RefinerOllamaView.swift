import SwiftUI

@MainActor
struct RefinerOllamaView: View {
    @ObservedObject var prefs: PreferencesStore
    let modelLister: () -> OllamaModelLister

    @State private var availableModels: [String] = []
    @State private var loading = false
    @State private var loadError: String?

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.refiner.ollama.endpoint.header", defaultValue: "Endpoint"))) {
                LabeledContent(String(localized: "preferences.refiner.ollama.baseURL", defaultValue: "Base URL")) {
                    TextField("", text: $prefs.ollamaBaseURL)
                        .frame(maxWidth: 280)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: prefs.ollamaBaseURL) { _, _ in
                            availableModels = []
                            Task { await loadModels() }
                        }
                }
            }
            Section(header: Text(String(localized: "preferences.refiner.ollama.model.header", defaultValue: "Modelo"))) {
                if loading {
                    ProgressView(String(localized: "preferences.refiner.ollama.loading", defaultValue: "Carregando lista…"))
                } else if let err = loadError {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle")
                        VStack(alignment: .leading) {
                            Text(err).foregroundStyle(.orange)
                            TextField(String(localized: "preferences.refiner.ollama.fallback.placeholder",
                                              defaultValue: "Digite o nome (ex: gemma4:e4b)"),
                                      text: $prefs.ollamaModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 280)
                        }
                    }
                } else {
                    Picker(String(localized: "preferences.refiner.ollama.model.label", defaultValue: "Modelo"),
                           selection: $prefs.ollamaModel) {
                        ForEach(modelsIncludingCurrent, id: \.self) { name in
                            Text(displayName(name)).tag(name)
                        }
                    }
                }
                Button(String(localized: "preferences.refiner.ollama.refresh", defaultValue: "Atualizar")) {
                    Task { await loadModels() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await loadModels() }
    }

    /// Lista exibida no Picker: união da lista de availableModels e do prefs.ollamaModel
    /// (garante que o modelo selecionado nunca some — aparece como "(não instalado)").
    private var modelsIncludingCurrent: [String] {
        if availableModels.contains(prefs.ollamaModel) || prefs.ollamaModel.isEmpty {
            return availableModels
        }
        return availableModels + [prefs.ollamaModel]
    }

    private func displayName(_ name: String) -> String {
        if name == prefs.ollamaModel && !availableModels.contains(name) {
            return "\(name) (não instalado)"
        }
        return name
    }

    private func loadModels() async {
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            availableModels = try await modelLister().availableModels()
        } catch {
            loadError = String(localized: "preferences.refiner.ollama.offline",
                                defaultValue: "Ollama offline. Digite o nome manualmente.")
        }
    }
}
