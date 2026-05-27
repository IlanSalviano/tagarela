import SwiftUI

/// Picker visual do idioma de transcrição (Automático · Português · English).
/// Mesmo padrão visual do `WhisperModelPicker` (radio custom + binding).
/// A troca vale na próxima transcrição — não recarrega o modelo (ADR-0006).
struct TranscriptionLanguagePicker: View {
    @Binding var selected: TranscriptionLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(TranscriptionLanguage.allCases, id: \.self) { lang in
                row(lang: lang)
            }
        }
    }

    @ViewBuilder
    private func row(lang: TranscriptionLanguage) -> some View {
        let isSelected = selected == lang
        Button(action: { selected = lang }) {
            HStack(spacing: 10) {
                Circle()
                    .stroke(DS.Color.ink, lineWidth: 1.2)
                    .background(isSelected ? Circle().fill(DS.Color.ink).padding(3) : nil)
                    .frame(width: 12, height: 12)
                Text(lang.displayName)
                    .font(DS.Font.mono(12, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(isSelected ? DS.Color.paper2 : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? DS.Color.ink : DS.Color.hairlineStrong, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var sel = TranscriptionLanguage.auto
    return TranscriptionLanguagePicker(selected: $sel)
        .padding(20)
        .frame(width: 480)
        .background(DS.Color.paper)
}
