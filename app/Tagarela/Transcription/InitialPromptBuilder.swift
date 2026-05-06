import Foundation

enum InitialPromptBuilder {
    /// Limite de tokens do prompt em chunked decode. Whisper tem janela total de
    /// 448 tokens; o segundo chunk de áudio >30s precisa caber prompt + previous
    /// text + geração. Acima de ~100 o decoder bail (gera só `<|endoftext|>`).
    /// Confirmado empíricamente em 2026-05-06 (177 tokens quebrava).
    static let maxTokens = 80

    /// Fallback char-based pessimista (3 chars/token) pra quando tokenizer não
    /// está disponível, ex: testes unitários.
    static let maxChars = maxTokens * 3

    /// Constrói prompt com base + vocab, dropando termos do final até caber no
    /// orçamento. Quando `tokenCount` é fornecido, usa contagem real do
    /// tokenizer; caso contrário, fallback char-based pessimista.
    static func build(vocab: [String], tokenCount: ((String) -> Int)? = nil) -> String {
        let base = "Transcrição em português brasileiro de desenvolvedor de software."
        guard !vocab.isEmpty else { return base }
        let suffix = " Termos esperados: "

        let cost: (String) -> Int = tokenCount ?? { $0.count }
        let limit = tokenCount != nil ? maxTokens : maxChars

        var terms = vocab
        while !terms.isEmpty {
            let candidate = base + suffix + terms.joined(separator: ", ") + "."
            if cost(candidate) <= limit { return candidate }
            terms.removeLast()
        }
        return base
    }
}
