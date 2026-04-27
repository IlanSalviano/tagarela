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
            let clamped = min(max(audioBoostMaxGain, PreferencesDefaults.audioBoostMaxGainRange.lowerBound),
                              PreferencesDefaults.audioBoostMaxGainRange.upperBound)
            if clamped != audioBoostMaxGain {
                audioBoostMaxGain = clamped // dispara didSet de novo, persiste
                return
            }
            defaults.set(audioBoostMaxGain, forKey: PreferencesKey.audioBoostMaxGain)
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
        self.audioBoostMaxGain = defaults.object(forKey: PreferencesKey.audioBoostMaxGain) as? Float
            ?? PreferencesDefaults.audioBoostMaxGain
    }
}
