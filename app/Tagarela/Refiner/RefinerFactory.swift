import Foundation

/// Lê estado atual do PreferencesStore + Keychain e devolve o TextRefiner concreto
/// + style ativo. Encapsula a decisão de qual refiner usar.
@MainActor
final class RefinerFactory {
    private let prefs: PreferencesStore
    private let styleProvider: StyleProvider
    private let openAI: () -> OpenAIRefiner
    private let ollama: () -> OllamaRefiner
    private let identity: IdentityRefiner

    init(prefs: PreferencesStore,
         styleProvider: StyleProvider,
         openAI: @escaping () -> OpenAIRefiner,
         ollama: @escaping () -> OllamaRefiner,
         identity: IdentityRefiner = IdentityRefiner()) {
        self.prefs = prefs
        self.styleProvider = styleProvider
        self.openAI = openAI
        self.ollama = ollama
        self.identity = identity
    }

    /// Retorna (refiner, style ativo). Style cru → identity sempre.
    func current() -> (refiner: TextRefiner, style: Style) {
        let style = styleProvider.styleOrDefault(for: prefs.selectedStyleID)
        if style.id == BuiltInStyles.cruSemReescrita.id {
            return (identity, style)
        }
        switch prefs.refinerKind {
        case .none:   return (identity, style)
        case .openai: return (openAI(), style)
        case .ollama: return (ollama(), style)
        }
    }
}
