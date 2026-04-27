import SwiftUI

struct BackendSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    /// Triggar abertura do modal de API key (vem do AppContainer via TagarelaApp).
    /// Na Tarefa 11 stub apenas loga; Tarefa 12 implementa a modal real.
    var onConfigureKey: () -> Void

    var body: some View {
        Menu {
            ForEach(RefinerKind.allCases, id: \.self) { kind in
                Button {
                    prefs.refinerKind = kind
                    if kind == .openai { onConfigureKey() }
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
                onConfigureKey()
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
