import SwiftUI

struct StyleSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    /// Observed pra disparar re-render quando custom styles são criados/apagados.
    /// SwiftUI só observa o tipo concreto (Live tem @Published; protocol não).
    @ObservedObject var customStore: CustomStyleStoreLive
    let styleProvider: StyleProvider

    /// Hash dos custom styles. Usado em `.id()` pra forçar refresh do Menu
    /// quando lista muda (insert/delete) OU itens individuais mudam (rename/edit).
    private var stylesFingerprint: Int {
        var hasher = Hasher()
        for s in customStore.styles {
            hasher.combine(s.id)
            hasher.combine(s.updatedAt)
        }
        return hasher.finalize()
    }

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
        // SwiftUI Menu cacheia o conteúdo de itens já renderizados — body
        // re-render por @Published não basta pra refrescar a lista do menu
        // já apresentado. Forçar identity-change com um fingerprint que
        // muda em insert/delete (count) E em rename/edit (updatedAt). T11
        // adiciona edit; sem isso, rename não aparece sem reabrir o menu.
        .id(stylesFingerprint)
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
