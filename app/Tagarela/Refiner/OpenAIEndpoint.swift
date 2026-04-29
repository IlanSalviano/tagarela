import Foundation

enum OpenAIProvider: String, Codable, CaseIterable, Sendable {
    case official
    case openrouter
    case lmstudio
    case custom
}

struct OpenAIEndpoint: Codable, Hashable, Sendable {
    var provider: OpenAIProvider
    var baseURL: URL
}

enum OpenAIEndpointDefaults {
    /// Default baseURL pra cada provider. .custom retorna nil (user define).
    static func defaultURL(for provider: OpenAIProvider) -> URL? {
        switch provider {
        case .official:   return URL(string: "https://api.openai.com/v1")
        case .openrouter: return URL(string: "https://openrouter.ai/api/v1")
        case .lmstudio:   return URL(string: "http://localhost:1234/v1")
        case .custom:     return nil
        }
    }
}
