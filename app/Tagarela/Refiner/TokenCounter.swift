import Foundation

/// Estimativa rápida e barata. Não é tokenizer real — usado só pra decidir
/// se vale truncar antes da chamada HTTP.
enum TokenCounter {
    static func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
