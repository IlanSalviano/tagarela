import Foundation

/// Helpers compartilhados entre OpenAIRefiner e OllamaRefiner: trunca-com-marcador,
/// retry de 1× ao exceder context, error mapping comum.
enum BaseRemoteRefiner {
    static let truncationMarker = "[…texto cortado…]"

    /// Retorna texto truncado se exceder context window. Mantém primeiros 40% chars +
    /// marker + últimos 40%. Se já cabe, retorna `nil` (não precisa truncar).
    static func truncatedIfNeeded(_ text: String, modelName: String, systemTokens: Int) -> String? {
        let estimated = TokenCounter.estimate(text) + systemTokens
        let window = RemoteRefinerConfig.contextWindow(for: modelName)
        let usable = Int(Double(window) * RemoteRefinerConfig.usableFraction)
        if estimated <= usable { return nil }

        let chars = Array(text)
        let cut = chars.count * 4 / 10  // 40% chars de cada ponta
        let head = String(chars[0..<cut])
        let tail = String(chars[(chars.count - cut)..<chars.count])
        return head + truncationMarker + tail
    }
}
