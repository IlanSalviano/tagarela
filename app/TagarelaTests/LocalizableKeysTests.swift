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
            // Fase 2d
            "transcription.picker.badge.recommended",
            "preferences.section.transcricao",
            "preferences.transcription.activeModel",
            "preferences.transcription.swapConfirm.title",
            "preferences.transcription.swapConfirm.body",
            "preferences.transcription.swapConfirm.proceed",
            "preferences.transcription.swap.downloading",
            "preferences.transcription.swap.swapping",
            "preferences.transcription.swap.error.title",
            "preferences.transcription.swap.error.body",
            "preferences.transcription.swap.error.retry",
            "preferences.transcription.swap.error.close",
            "preferences.transcription.deletePrevious.title",
            "preferences.transcription.deletePrevious.body",
            "preferences.transcription.deletePrevious.keep",
            "preferences.transcription.deletePrevious.delete",
            "onboarding.model.error",
            "preferences.section.about",
            "about.tagline",
            "about.author.header",
            "about.coauthor.header",
            "about.coauthor.note",
        ]
        for k in keys {
            let resolved = String(localized: String.LocalizationValue(k))
            XCTAssertNotEqual(resolved, k, "chave '\(k)' não resolve em Localizable")
        }
    }
}
