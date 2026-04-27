import Foundation

protocol TextRefiner: AnyObject {
    /// Recebe texto cru e retorna texto refinado. `style` é o nome do estilo
    /// selecionado; implementações simples (Identity) ignoram.
    func refine(_ raw: String, style: String) async throws -> String

    var kind: RefinerKind { get }
}

enum RefinerKind: String, Codable, Equatable {
    case identity
    case ollama
    case openai
}
