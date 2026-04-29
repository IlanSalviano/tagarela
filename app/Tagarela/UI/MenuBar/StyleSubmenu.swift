import SwiftUI

struct StyleSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    /// Observed pra disparar re-render quando custom styles são criados/apagados.
    /// SwiftUI só observa o tipo concreto (Live tem @Published; protocol não).
    @ObservedObject var customStore: CustomStyleStoreLive
    let styleProvider: StyleProvider

    var body: some View {
        HStack {
            Text(NSLocalizedString("menubar.style.label", value: "Estilo", comment: ""))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.ink2)
            Spacer()
            Menu {
                ForEach(styleProvider.all) { style in
                    Button {
                        prefs.selectedStyleID = style.id
                    } label: {
                        HStack {
                            Text(style.name)
                            Spacer()
                            if prefs.selectedStyleID == style.id { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Text(activeStyleName)
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        // Acessar customStore.styles dentro do body força SwiftUI a observar
        // mudanças no @Published. styleProvider.all já lê isso indiretamente,
        // mas quando o ForEach está dentro de um Menu fechado, a leitura só
        // acontece ao abrir o menu. Garantir presença explicita aqui.
        .id(customStore.styles.count)
    }

    private var activeStyleName: String {
        styleProvider.style(for: prefs.selectedStyleID)?.name ?? "—"
    }
}

/// Fallback usado quando o CustomStyleStoreLive não está disponível
/// (ModelContainer falhou). Sem @ObservedObject, sem reactivity — usa
/// só built-ins. Caso degenerado.
struct StyleSubmenuStaticFallback: View {
    @ObservedObject var prefs: PreferencesStore
    let styleProvider: StyleProvider

    var body: some View {
        HStack {
            Text(NSLocalizedString("menubar.style.label", value: "Estilo", comment: ""))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.ink2)
            Spacer()
            Menu {
                ForEach(styleProvider.all) { style in
                    Button {
                        prefs.selectedStyleID = style.id
                    } label: {
                        HStack {
                            Text(style.name)
                            Spacer()
                            if prefs.selectedStyleID == style.id { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Text(styleProvider.style(for: prefs.selectedStyleID)?.name ?? "—")
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}
