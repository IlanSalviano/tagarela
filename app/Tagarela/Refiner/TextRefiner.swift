import Foundation

protocol TextRefiner: AnyObject, Sendable {
    /// Recebe texto cru e o `Style` ativo. Refiner concreto monta system+user prompt
    /// como achar conveniente.
    func refine(_ raw: String, style: Style) async throws -> String

    var kind: RefinerKind { get }
}

enum RefinerKind: String, Codable, Equatable, CaseIterable, Sendable {
    case none
    case ollama
    case openai
}
