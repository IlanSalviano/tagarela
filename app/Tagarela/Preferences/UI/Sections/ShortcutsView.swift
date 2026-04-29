import SwiftUI

struct ShortcutsView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.shortcuts.header", defaultValue: "Atalhos atuais"))) {
                LabeledContent(String(localized: "preferences.shortcuts.toggle",
                                       defaultValue: "Iniciar/parar ditado")) {
                    Text(String(localized: "preferences.shortcuts.toggle.value",
                                 defaultValue: "⌥ direito"))
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent(String(localized: "preferences.shortcuts.cancel",
                                       defaultValue: "Cancelar")) {
                    Text("Esc").font(.system(.body, design: .monospaced))
                }
                Text(String(localized: "preferences.shortcuts.help",
                             defaultValue: "Atalhos customizáveis chegam em uma versão futura."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
