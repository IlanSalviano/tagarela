import Combine
import Foundation

/// Wrapper de UserDefaults com properties @Published pra Combine.
/// Single source of truth pra config persistente que precisa reagir em UI.
@MainActor
final class PreferencesStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var refinerKind: RefinerKind {
        didSet { defaults.set(refinerKind.rawValue, forKey: PreferencesKey.refinerKind) }
    }
    @Published var selectedStyleID: UUID {
        didSet { defaults.set(selectedStyleID.uuidString, forKey: PreferencesKey.selectedStyleID) }
    }
    @Published var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: PreferencesKey.openAIModel) }
    }
    @Published var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: PreferencesKey.ollamaBaseURL) }
    }
    @Published var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: PreferencesKey.ollamaModel) }
    }
    @Published var refinerTimeoutSec: Double {
        didSet { defaults.set(refinerTimeoutSec, forKey: PreferencesKey.refinerTimeoutSec) }
    }
    @Published var technicalVocabulary: [String] {
        didSet { defaults.set(technicalVocabulary, forKey: PreferencesKey.technicalVocabulary) }
    }
    @Published var historyMaxItems: Int {
        didSet { defaults.set(historyMaxItems, forKey: PreferencesKey.historyMaxItems) }
    }
    @Published var historyMaxDays: Int {
        didSet { defaults.set(historyMaxDays, forKey: PreferencesKey.historyMaxDays) }
    }
    @Published var audioBoostMaxGain: Float {
        didSet {
            defaults.set(audioBoostMaxGain, forKey: PreferencesKey.audioBoostMaxGain)
        }
    }
    @Published var openAIEndpoint: OpenAIEndpoint {
        didSet {
            // try? é seguro aqui: OpenAIEndpoint só tem String + URL (codifica como String).
            // Se um campo não-Codable for adicionado no futuro, este try? mascara o erro —
            // adicionar log ou trocar pra try! com fatalError em debug.
            if let data = try? JSONEncoder().encode(openAIEndpoint) {
                defaults.set(data, forKey: PreferencesKey.openAIEndpoint)
            }
        }
    }

    init(defaults: UserDefaults = .standard,
         defaultStyleID: UUID) {
        self.defaults = defaults

        let kindRaw = defaults.string(forKey: PreferencesKey.refinerKind) ?? PreferencesDefaults.refinerKind.rawValue
        self.refinerKind = RefinerKind(rawValue: kindRaw) ?? PreferencesDefaults.refinerKind

        let idRaw = defaults.string(forKey: PreferencesKey.selectedStyleID)
        self.selectedStyleID = idRaw.flatMap(UUID.init(uuidString:)) ?? defaultStyleID

        self.openAIModel = defaults.string(forKey: PreferencesKey.openAIModel)
            ?? PreferencesDefaults.openAIModel
        self.ollamaBaseURL = defaults.string(forKey: PreferencesKey.ollamaBaseURL)
            ?? PreferencesDefaults.ollamaBaseURL
        self.ollamaModel = defaults.string(forKey: PreferencesKey.ollamaModel)
            ?? PreferencesDefaults.ollamaModel
        self.refinerTimeoutSec = defaults.object(forKey: PreferencesKey.refinerTimeoutSec) as? Double
            ?? PreferencesDefaults.refinerTimeoutSec
        self.technicalVocabulary = defaults.stringArray(forKey: PreferencesKey.technicalVocabulary)
            ?? [] // populado depois pelo init do AppContainer com DefaultVocabulary.terms
        self.historyMaxItems = defaults.object(forKey: PreferencesKey.historyMaxItems) as? Int
            ?? PreferencesDefaults.historyMaxItems
        self.historyMaxDays = defaults.object(forKey: PreferencesKey.historyMaxDays) as? Int
            ?? PreferencesDefaults.historyMaxDays

        // audioBoostMaxGain: usar defaults.float(forKey:) com check de existência
        // para evitar falha na conversão NSNumber -> Float
        if defaults.object(forKey: PreferencesKey.audioBoostMaxGain) != nil {
            let stored = defaults.float(forKey: PreferencesKey.audioBoostMaxGain)
            self.audioBoostMaxGain = min(max(stored, PreferencesDefaults.audioBoostMaxGainRange.lowerBound),
                                          PreferencesDefaults.audioBoostMaxGainRange.upperBound)
        } else {
            self.audioBoostMaxGain = PreferencesDefaults.audioBoostMaxGain
        }

        if let data = defaults.data(forKey: PreferencesKey.openAIEndpoint),
           let decoded = try? JSONDecoder().decode(OpenAIEndpoint.self, from: data) {
            self.openAIEndpoint = decoded
        } else {
            self.openAIEndpoint = PreferencesDefaults.openAIEndpoint
        }
    }

    /// Setter que clampa pro range válido [1, 50] antes de publicar.
    /// Use isto em vez de atribuir audioBoostMaxGain direto quando vier
    /// de input externo (slider, defaults write etc.).
    func setAudioBoostMaxGain(_ value: Float) {
        audioBoostMaxGain = min(max(value, PreferencesDefaults.audioBoostMaxGainRange.lowerBound),
                                PreferencesDefaults.audioBoostMaxGainRange.upperBound)
    }

    /// Setter clampado pra historyMaxItems. Mínimo 1 (zero ou negativo bloqueia retenção).
    /// Use isto em vez de atribuir direto quando vier de input externo (TextField etc.).
    func setHistoryMaxItems(_ value: Int) {
        historyMaxItems = max(1, value)
    }

    /// Setter clampado pra historyMaxDays. Mínimo 1.
    func setHistoryMaxDays(_ value: Int) {
        historyMaxDays = max(1, value)
    }
}
