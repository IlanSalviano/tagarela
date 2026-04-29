import SwiftUI

struct HistoryView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.history.retention.header",
                                         defaultValue: "Retenção"))) {
                LabeledContent(String(localized: "preferences.history.maxItems", defaultValue: "Máximo de itens")) {
                    TextField("", value: $prefs.historyMaxItems, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "preferences.history.maxDays", defaultValue: "Máximo de dias")) {
                    TextField("", value: $prefs.historyMaxDays, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                Text(String(localized: "preferences.history.help",
                             defaultValue: "Histórico é truncado a cada nova captura, mantendo o menor entre os dois limites."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
