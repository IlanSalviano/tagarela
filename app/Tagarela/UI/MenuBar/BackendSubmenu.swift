import SwiftUI

struct BackendSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    /// Disparado quando user seleciona OpenAI no submenu E a key ainda não está cadastrada.
    /// Recebe o backend anterior pra eventual rollback se o user cancelar o modal.
    var onSelectOpenAINeedsKey: (RefinerKind) -> Void
    /// Disparado pelo item explícito "Configurar API key da OpenAI…" — sempre abre modal.
    var onExplicitConfigureKey: () -> Void

    var body: some View {
        HStack {
            Text(NSLocalizedString("menubar.backend.label", value: "Backend", comment: ""))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.ink2)
            Spacer()
            Menu {
                ForEach(RefinerKind.allCases, id: \.self) { kind in
                    Button {
                        let previous = prefs.refinerKind
                        prefs.refinerKind = kind
                        if kind == .openai {
                            onSelectOpenAINeedsKey(previous)
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
                Text(label(for: prefs.refinerKind))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func label(for kind: RefinerKind) -> String {
        switch kind {
        case .none:   return NSLocalizedString("backend.none",   value: "Sem LLM",  comment: "")
        case .openai: return NSLocalizedString("backend.openai", value: "OpenAI",   comment: "")
        case .ollama: return NSLocalizedString("backend.ollama", value: "Ollama",   comment: "")
        }
    }
}
