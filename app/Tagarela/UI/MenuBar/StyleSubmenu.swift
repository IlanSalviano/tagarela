import SwiftUI

struct StyleSubmenu: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Menu {
            ForEach(BuiltInStyles.all) { style in
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
            HStack {
                Text(NSLocalizedString("menubar.style.label", value: "Estilo", comment: ""))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                Spacer()
                Text(activeStyleName)
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .menuStyle(.borderlessButton)
    }

    private var activeStyleName: String {
        BuiltInStyles.style(for: prefs.selectedStyleID)?.name ?? "—"
    }
}
