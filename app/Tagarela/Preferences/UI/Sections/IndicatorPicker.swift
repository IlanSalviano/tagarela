import SwiftUI

@MainActor
struct IndicatorPicker: View {
    @ObservedObject var prefs: PreferencesStore
    let indicatorPanel: FloatingIndicatorPanel

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 10)]
    private let previewState = PipelineState.recording(elapsedSeconds: 8, audioLevel: 0.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "preferences.geral.indicator.label",
                         defaultValue: "Estilo do indicador"))
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(IndicatorVariant.allCases, id: \.self) { variant in
                    card(variant)
                }
            }
            Button(String(localized: "preferences.geral.indicator.preview",
                           defaultValue: "Visualizar selecionado por 3s")) {
                indicatorPanel.showPreview(variant: prefs.indicatorVariant,
                                            state: previewState,
                                            durationSec: 3)
            }
            .padding(.top, 4)
        }
    }

    private func card(_ variant: IndicatorVariant) -> some View {
        VStack(spacing: 8) {
            ZStack {
                FloatingIndicatorPanel.indicator(
                    for: variant,
                    state: previewState,
                    onCancel: {})
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, maxHeight: 88)
            }
            .frame(height: 96)
            .background(variant.isDarkOnly ? Color.black.opacity(0.85) : DS.Color.paper2,
                         in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text(variant.displayName)
                    .font(.callout).bold()
                Spacer()
                if prefs.indicatorVariant == variant {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(prefs.indicatorVariant == variant ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: prefs.indicatorVariant == variant ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { prefs.indicatorVariant = variant }
    }
}
