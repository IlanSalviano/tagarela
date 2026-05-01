import SwiftUI

/// Picker visual de modelo Whisper, compartilhado entre Onboarding e Preferências.
///
/// Renderiza uma linha por entrada do `WhisperModelCatalog.all` com radio,
/// nome técnico, tamanho/RAM display, e badge "RECOM." pros recomendados.
/// Quando `enabled == false`, todas as linhas ficam não-clicáveis (mas
/// continuam destacando a seleção atual — usado durante swap em curso).
struct WhisperModelPicker: View {
    @Binding var selected: String
    let enabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(WhisperModelCatalog.all) { model in
                row(model: model)
            }
        }
    }

    @ViewBuilder
    private func row(model: WhisperModelInfo) -> some View {
        let isSelected = selected == model.name
        Button(action: { if enabled { selected = model.name } }) {
            HStack(spacing: 10) {
                Circle()
                    .stroke(DS.Color.ink, lineWidth: 1.2)
                    .background(isSelected ? Circle().fill(DS.Color.ink).padding(3) : nil)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(DS.Font.mono(12, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                    Text("\(model.displaySize) · \(model.displayRAM) RAM")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                }
                Spacer()
                if model.recommended {
                    Text(String(localized: "transcription.picker.badge.recommended",
                                 defaultValue: "RECOM."))
                        .font(DS.Font.mono(9))
                        .tracking(1)
                        .foregroundStyle(DS.Color.carmine)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .stroke(DS.Color.carmine, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(isSelected ? DS.Color.paper2 : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? DS.Color.ink : DS.Color.hairlineStrong, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.6)
    }
}

#Preview {
    @Previewable @State var sel = "large-v3-turbo"
    return WhisperModelPicker(selected: $sel, enabled: true)
        .padding(20)
        .frame(width: 480)
        .background(DS.Color.paper)
}
