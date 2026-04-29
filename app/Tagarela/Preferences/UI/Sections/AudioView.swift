import SwiftUI

struct AudioView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.audio.boost.header", defaultValue: "Ganho de áudio"))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "preferences.audio.maxgain.label", defaultValue: "Ganho máximo:"))
                        Spacer()
                        Text(String(format: "%.1f×", prefs.audioBoostMaxGain))
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { prefs.audioBoostMaxGain },
                        set: { prefs.setAudioBoostMaxGain($0) }
                    ), in: PreferencesDefaults.audioBoostMaxGainRange,
                       step: 1.0)
                    Text(String(localized: "preferences.audio.maxgain.help",
                                 defaultValue: "Compensa input gain baixo do microfone. Padrão: 20×."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
