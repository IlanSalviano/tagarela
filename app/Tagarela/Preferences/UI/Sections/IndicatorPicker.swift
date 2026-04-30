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
        let size = previewVisualSize(variant)
        return VStack(spacing: 8) {
            ZStack {
                FloatingIndicatorPanel.indicator(
                    for: variant,
                    state: previewState,
                    onCancel: {})
                    .scaleEffect(0.6, anchor: .center)
                    .frame(width: size.width, height: size.height, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipped()
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

    // Tamanho visual após scaleEffect 0.6 — colapsa o layout box de cada
    // variante pra que o ZStack centre todos pelo CENTRO VISUAL, em vez
    // de centrar pelo bounding-box natural (Orb 92×108 vs HUD 300×80
    // tem centros visuais em alturas distintas se não normalizar).
    private func previewVisualSize(_ variant: IndicatorVariant) -> CGSize {
        switch variant {
        case .pill:     return CGSize(width: 90, height: 24)
        case .orb:      return CGSize(width: 60, height: 70)
        case .vertical: return CGSize(width: 22, height: 100)
        case .hud:      return CGSize(width: 180, height: 48)
        }
    }
}
