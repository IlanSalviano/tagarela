import Foundation

enum BuiltInStyles {
    private static let codeSwitchingClause = """

    Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro \
    (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper \
    (ex: 'loquei' → 'log it', 'diploiei' → 'deployei'). \
    Se preservar oralidade está ativo, mantenha contrações orais ('tô', 'pra', 'cê').
    """

    static let conversaInformal = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
        name: "conversa informal",
        systemPrompt: """
        Você refina ditados de voz em português brasileiro.
        Remova muletas ('tipo', 'aí', 'então' repetidos), corrija pontuação e \
        capitalização, mas mantenha o tom informal e a estrutura da fala. \
        Não adicione informação que não estava no original.
        """ + codeSwitchingClause,
        preserveOrality: true,
        isBuiltIn: true)

    static let emailProfissional = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
        name: "e-mail profissional",
        systemPrompt: """
        Você refina ditados de voz pra virarem texto de e-mail profissional em \
        português brasileiro. Use estrutura clara, tom cordial mas direto, \
        pontuação completa. Corrija oralidades e contrações ('tô' → 'estou', \
        'pra' → 'para'). Não adicione informação que não estava no original.
        """ + codeSwitchingClause,
        preserveOrality: false,
        isBuiltIn: true)

    static let notasTecnicas = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
        name: "notas técnicas",
        systemPrompt: """
        Você refina ditados de voz pra virarem notas técnicas em português \
        brasileiro. Estrutura concisa, frases diretas, pontuação clara. \
        Preserve nomes próprios, siglas e termos técnicos exatamente como ditos. \
        Não adicione interpretação além do que foi dito.
        """ + codeSwitchingClause,
        preserveOrality: false,
        isBuiltIn: true)

    static let cruSemReescrita = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
        name: "cru — sem reescrita",
        systemPrompt: "",  // sentinel: pipeline pula refiner inteiro
        preserveOrality: true,
        isBuiltIn: true)

    static let all: [Style] = [conversaInformal, emailProfissional, notasTecnicas, cruSemReescrita]

    static func style(for id: UUID) -> Style? {
        all.first { $0.id == id }
    }

    static let defaultStyleID: UUID = conversaInformal.id
}
