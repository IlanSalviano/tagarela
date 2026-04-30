import SwiftUI

/// Conformidade pras 4 variações do indicator flutuante. Cada View toma
/// o `PipelineState` atual e uma closure `onCancel`. `FloatingIndicatorPanel`
/// faz dispatch via `prefs.indicatorVariant` ao rebuildar.
protocol IndicatorView: View {
    init(state: PipelineState, onCancel: @escaping () -> Void)
}
