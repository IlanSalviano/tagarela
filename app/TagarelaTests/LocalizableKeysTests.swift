import XCTest

final class LocalizableKeysTests: XCTestCase {
    /// Smoke: chaves principais resolvem em pt-BR (não retornam a key bruta).
    /// O `String(localized:)` lê de Localizable.strings (pt-BR).
    /// Se a chave não tiver entrada, retorna a key bruta — o que indica regressão.
    func test_principalKeys_resolveInPtBR() {
        let keys: [String] = [
            "preferences.section.geral",
            "preferences.section.estilos",
            "preferences.refiner.openai.provider.header",
            "preferences.audio.maxgain.label",
            "preferences.shortcuts.toggle",
            "styles.add",
            "common.cancel",
            "common.save",
            "styles.edit.discipline.toggle",
            "styles.edit.discipline.help",
            "styles.edit.discipline.warning",
        ]
        for k in keys {
            let resolved = String(localized: String.LocalizationValue(k))
            XCTAssertNotEqual(resolved, k, "chave '\(k)' não resolve em Localizable")
        }
    }
}
