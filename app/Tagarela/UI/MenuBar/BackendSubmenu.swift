import SwiftUI

struct BackendSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    /// Disparado quando user seleciona OpenAI no submenu E a key ainda não está cadastrada.
    /// O caller decide se abre modal e/ou reverte refinerKind se cancelar.
    var onSelectOpenAINeedsKey: () -> Void
    /// Disparado pelo item explícito "Configurar API key da OpenAI…" — sempre abre modal.
    var onExplicitConfigureKey: () -> Void

    var body: some View {
        Menu {
            ForEach(RefinerKind.allCases, id: \.self) { kind in
                Button {
                    let previous = prefs.refinerKind
                    prefs.refinerKind = kind
                    if kind == .openai {
                        // O caller checa Keychain. Se vazio → onSelectOpenAINeedsKey + revert se cancelar.
                        onSelectOpenAINeedsKey()
                        _ = previous // captured pra eventual rollback no caller
                    }
                } label: {
                    HStack {
                        Text(label(for: kind))
                        Spacer()
                        if prefs.refinerKind == kind { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button(NSLocalizedString("menubar.configure.openaikey",
                                     value: "Configurar API key da OpenAI…",
                                     comment: "")) {
                onExplicitConfigureKey()
            }
        } label: {
            HStack {
                Text(NSLocalizedString("menubar.backend.label", value: "Backend", comment: ""))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                Spacer()
                Text(label(for: prefs.refinerKind))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .menuStyle(.borderlessButton)
    }

    private func label(for kind: RefinerKind) -> String {
        switch kind {
        case .none:   return NSLocalizedString("backend.none",   value: "Sem LLM",  comment: "")
        case .openai: return NSLocalizedString("backend.openai", value: "OpenAI",   comment: "")
        case .ollama: return NSLocalizedString("backend.ollama", value: "Ollama",   comment: "")
        }
    }
}
