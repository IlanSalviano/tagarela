import SwiftUI

/// Variação C — barra vertical fina (28×120). Dot pulsante carmim no topo,
/// waveform vertical no meio, timer rotacionado abaixo.
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
            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    let intensity = max(0, level - Double(i) * 0.12)
                    Rectangle()
                        .fill(dotColor.opacity(0.3 + intensity * 0.7))
                        .frame(width: 4, height: 6)
                }
            }
            Text(formatted)
                .font(DS.Font.mono(9))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 38)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(DS.Color.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
        .dsShadowPop()
        .frame(width: 28, height: 120)
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
