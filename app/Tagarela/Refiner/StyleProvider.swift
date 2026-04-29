import Foundation

@MainActor
final class StyleProvider {
    private let customStore: CustomStyleStore

    init(customStore: CustomStyleStore) {
        self.customStore = customStore
    }

    /// Lista combinada built-in + custom, ordenada por nome (case-insensitive).
    var all: [Style] {
        let builtIns = BuiltInStyles.all
        let customs = customStore.styles.map { $0.asStyle() }
        return (builtIns + customs).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Resolve um Style pelo UUID. Procura primeiro nos built-ins (UUIDs estáveis),
    /// depois nos custom. Retorna nil se nenhum bate.
    func style(for id: UUID) -> Style? {
        if let b = BuiltInStyles.style(for: id) { return b }
        return customStore.styles.first { $0.id == id }?.asStyle()
    }

    /// Style ativo dado um ID; cai pra defaultStyleID se não encontra.
    func styleOrDefault(for id: UUID) -> Style {
        style(for: id) ?? BuiltInStyles.style(for: BuiltInStyles.defaultStyleID)!
    }
}
