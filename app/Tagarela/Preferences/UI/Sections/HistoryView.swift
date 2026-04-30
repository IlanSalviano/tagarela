import SwiftUI

struct HistoryView: View {
    @ObservedObject var prefs: PreferencesStore
    let historyStore: HistoryStore
    let injector: Injecting

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.history.retention.header",
                                         defaultValue: "Retenção"))) {
                LabeledContent(String(localized: "preferences.history.maxItems", defaultValue: "Máximo de itens")) {
                    TextField("", value: Binding(
                        get: { prefs.historyMaxItems },
                        set: { prefs.setHistoryMaxItems($0) }
                    ), format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "preferences.history.maxDays", defaultValue: "Máximo de dias")) {
                    TextField("", value: Binding(
                        get: { prefs.historyMaxDays },
                        set: { prefs.setHistoryMaxDays($0) }
                    ), format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                Text(String(localized: "preferences.history.help",
                             defaultValue: "Histórico é truncado a cada nova captura, mantendo o menor entre os dois limites."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(header: Text(String(localized: "preferences.history.records.header",
                                         defaultValue: "Registros"))) {
                HistoryListView(historyStore: historyStore,
                                injector: injector,
                                limitProvider: { prefs.historyMaxItems })
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
