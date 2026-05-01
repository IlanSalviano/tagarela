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
    static let openAIEndpoint       = "com.tagarela.preferences.openAIEndpoint"
    static let indicatorVariant     = "com.tagarela.preferences.indicatorVariant"
    static let whisperModelName     = "com.tagarela.preferences.whisperModelName"
}

enum PreferencesDefaults {
    static let refinerKind: RefinerKind   = .none
    static let openAIModel: String        = "gpt-5.4-mini"
    static let ollamaBaseURL: String      = "http://localhost:11434"
    // gemma4:e4b: modelo sem chain-of-thought. Trocado de qwen3.5:9b-nvfp4 (thinking)
    // que estourava timeout default e caía em fallback Identity silencioso. Ver
    // tagarela_docs/04-decisoes/cleanup-fase2a.md item 1.
    static let ollamaModel: String        = "gemma4:e4b"
    // 60s: margem extra pra Ollama em modelos maiores ou primeira inferência (cold).
    static let refinerTimeoutSec: Double  = 60
    static let historyMaxItems: Int       = 200
    static let historyMaxDays: Int        = 30
    static let audioBoostMaxGain: Float   = 20.0
    static let audioBoostMaxGainRange: ClosedRange<Float> = 1...50
    static let openAIEndpoint: OpenAIEndpoint = OpenAIEndpoint(
        provider: .official,
        baseURL: OpenAIEndpointDefaults.defaultURL(for: .official)!)
    static let indicatorVariant: IndicatorVariant = .pill
    static let whisperModelName: String   = "large-v3_turbo"
}
