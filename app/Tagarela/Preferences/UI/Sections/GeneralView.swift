import SwiftUI

struct GeneralView: View {
    @ObservedObject var prefs: PreferencesStore
    let indicatorPanel: FloatingIndicatorPanel

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.geral.about.header", defaultValue: "Sobre"))) {
                LabeledContent(String(localized: "preferences.geral.version", defaultValue: "Versão")) {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
                LabeledContent(String(localized: "preferences.geral.build", defaultValue: "Build")) {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                }
            }
            Section {
                IndicatorPicker(prefs: prefs, indicatorPanel: indicatorPanel)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
