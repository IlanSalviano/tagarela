import SwiftUI

struct VocabularyView: View {
    @ObservedObject var prefs: PreferencesStore
    @State private var text: String = ""

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.vocab.header", defaultValue: "Vocabulário técnico"))) {
                Text(String(localized: "preferences.vocab.help",
                             defaultValue: "Termos passados como initial prompt pro Whisper, melhorando reconhecimento de jargão. Um por linha."))
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { text = prefs.technicalVocabulary.joined(separator: "\n") }
        .onChange(of: text) { _, newValue in
            prefs.technicalVocabulary = newValue
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
}
