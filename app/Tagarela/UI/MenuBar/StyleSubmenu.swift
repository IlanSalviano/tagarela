import SwiftUI

struct StyleSubmenu: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        HStack {
            Text(NSLocalizedString("menubar.style.label", value: "Estilo", comment: ""))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.ink2)
            Spacer()
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
                Text(activeStyleName)
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var activeStyleName: String {
        BuiltInStyles.style(for: prefs.selectedStyleID)?.name ?? "—"
    }
}
