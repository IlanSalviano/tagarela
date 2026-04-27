import Foundation

enum InitialPromptBuilder {
    /// Limite conservador: Whisper aceita ~224 tokens; ~4 chars por token em PT;
    /// reservamos folga pro contexto base.
    private static let maxChars = 700

    static func build(vocab: [String]) -> String {
        let base = "Transcrição em português brasileiro de desenvolvedor de software."
        guard !vocab.isEmpty else { return base }
        var list = vocab.joined(separator: ", ")
        let suffix = " Termos esperados: "
        let budget = maxChars - base.count - suffix.count
        if list.count > budget {
            list = String(list.prefix(budget))
            if let lastComma = list.lastIndex(of: ",") {
                list = String(list[..<lastComma])
            }
        }
        return base + suffix + list + "."
    }
}
