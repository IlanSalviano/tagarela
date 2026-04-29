import Foundation

enum PreferencesKey {
    static let refinerKind          = "com.tagarela.preferences.refinerKind"
    static let selectedStyleID      = "com.tagarela.preferences.selectedStyleID"
    static let openAIModel          = "com.tagarela.preferences.openAIModel"
    static let ollamaBaseURL        = "com.tagarela.preferences.ollamaBaseURL"
    static let ollamaModel          = "com.tagarela.preferences.ollamaModel"
    static let refinerTimeoutSec    = "com.tagarela.preferences.refinerTimeoutSec"
    static let technicalVocabulary  = "com.tagarela.preferences.technicalVocabulary"
    static let historyMaxItems      = "com.tagarela.preferences.historyMaxItems"
    static let historyMaxDays       = "com.tagarela.preferences.historyMaxDays"
    static let audioBoostMaxGain    = "com.tagarela.preferences.audioBoostMaxGain"
}

enum PreferencesDefaults {
    static let refinerKind: RefinerKind   = .none
    static let openAIModel: String        = "gpt-5.4-mini"
    static let ollamaBaseURL: String      = "http://localhost:11434"
    static let ollamaModel: String        = "qwen3.5:9b-nvfp4"
    static let refinerTimeoutSec: Double  = 30
    static let historyMaxItems: Int       = 200
    static let historyMaxDays: Int        = 30
    static let audioBoostMaxGain: Float   = 20.0
    static let audioBoostMaxGainRange: ClosedRange<Float> = 1...50
}
