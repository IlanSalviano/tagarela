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

    /// Cláusula obrigatória prefixada em todo custom style. Built-ins têm proteção
    /// equivalente embutida em seus prompts ("Você refina ditados de voz... Não
    /// adicione informação que não estava no original"). Sem isso, custom styles
    /// se comportam como chat assistant: o LLM trata o input como pergunta e
    /// responde, em vez de reescrever. Bug 12.2 do aceite manual da Fase 2b-1.
    static let rewriterDiscipline = """
    Você é um pós-processador de transcrição de voz em português brasileiro. \
    NÃO responda ao que foi dito; apenas reescreva o ditado seguindo as regras abaixo. \
    NÃO adicione informação além do que foi falado. NÃO faça comentários, perguntas \
    ou interpretações.

    Regras de reescrita:

    """

    /// Converte o `CustomStyle` num `Style` consumível pelo `RefinerFactory`/refiners.
    /// Anexa: (1) `rewriterDiscipline` sempre (proteção contra LLM responder em vez
    /// de transcrever), (2) cláusula de code-switching opcional via toggle.
    func asStyle() -> Style {
        let codeSwitchingClause = """

        Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro \
        (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper \
        (ex: 'loquei' → 'log it', 'diploiei' → 'deployei').
        """
        var prompt = CustomStyle.rewriterDiscipline + systemPrompt
        if appendCodeSwitching { prompt += codeSwitchingClause }
        return Style(id: id,
                     name: name,
                     systemPrompt: prompt,
                     preserveOrality: false,
                     isBuiltIn: false)
    }
}
