import Foundation

/// Tabela de context windows aproximadas por modelo. Usada por BaseRemoteRefiner
/// pra decidir se trunca antes de chamar a API.
enum RemoteRefinerConfig {
    static let conservativeFallback = 8_000

    static func contextWindow(for modelName: String) -> Int {
        let lower = modelName.lowercased()
        if lower.hasPrefix("gpt-5.4") { return 200_000 }
        if lower.hasPrefix("qwen3")   { return 32_768 }
        if lower.hasPrefix("llama3.2"){ return 128_000 }
        return conservativeFallback
    }

    /// Reserva 20% pra completion + system prompt.
    static let usableFraction: Double = 0.8
}
