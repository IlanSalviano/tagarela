import Foundation
import SwiftData

@Model
final class CustomStyle {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var appendCodeSwitching: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         name: String,
         systemPrompt: String,
         appendCodeSwitching: Bool,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.appendCodeSwitching = appendCodeSwitching
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Converte o `CustomStyle` num `Style` consumível pelo `RefinerFactory`/refiners.
    /// Cláusula de code-switching é anexada igual aos built-ins (BuiltInStyles).
    func asStyle() -> Style {
        let codeSwitchingClause = """

        Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro \
        (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper \
        (ex: 'loquei' → 'log it', 'diploiei' → 'deployei').
        """
        let prompt = appendCodeSwitching ? systemPrompt + codeSwitchingClause : systemPrompt
        return Style(id: id,
                     name: name,
                     systemPrompt: prompt,
                     preserveOrality: false,
                     isBuiltIn: false)
    }
}
