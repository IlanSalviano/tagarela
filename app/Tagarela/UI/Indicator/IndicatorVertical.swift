import SwiftUI

/// Variação C — barra vertical fina (32×160). Dot pulsante carmim no topo,
/// 8 barrinhas reagindo ao audio level, timer rotacionado abaixo.
struct IndicatorVertical: View, IndicatorView {
    let state: PipelineState
    var onCancel: () -> Void

    init(state: PipelineState, onCancel: @escaping () -> Void = {}) {
        self.state = state
        self.onCancel = onCancel
    }

    private var levelAndSeconds: (level: Double, seconds: Double) {
        if case .recording(let secs, let lvl) = state { return (lvl, secs) }
        return (0, 0)
    }

    private var dotColor: Color {
        switch state {
        case .recording: return DS.Color.carmine
        case .processing, .refining: return DS.Color.amber
        case .error: return DS.Color.carmineDeep
        case .idle: return DS.Color.ink
        }
    }

    private var formatted: String {
        let (_, seconds) = levelAndSeconds
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        let (level, _) = levelAndSeconds
        VStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .modifier(PulseIfRecordingVertical(state: state))
            // 8 barrinhas altura fixa que mudam opacity conforme audio level.
            // Cada barra "acende" em threshold crescente — visualmente é
            // uma régua de volume. Mantém altura fixa pra caber no frame.
            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    let threshold = Double(i) * 0.04
                    let active = max(0, min(1, (level - threshold) * 10))
                    Rectangle()
                        .fill(dotColor.opacity(0.2 + active * 0.8))
                        .frame(width: 6, height: 7)
                        .animation(.easeOut(duration: 0.08), value: level)
                }
            }
            Text(formatted)
                .font(DS.Font.mono(9))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 38)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(DS.Color.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
        .dsShadowPop()
        .frame(width: 32, height: 160)
        .contentShape(Rectangle())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecordingVertical: ViewModifier {
    let state: PipelineState
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing && isRecording ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
}

#Preview {
    HStack(spacing: 20) {
        IndicatorVertical(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorVertical(state: .processing)
        IndicatorVertical(state: .refining)
        IndicatorVertical(state: .error(message: "erro"))
    }
    .padding(40)
    .background(DS.Color.paper2)
}
