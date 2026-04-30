import SwiftUI

/// Variação B — orb radial 92×92. Dot pulsante carmim no centro,
/// ring com waveform circular, timer mono abaixo.
struct IndicatorOrb: View, IndicatorView {
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
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(DS.Color.hairlineStrong, lineWidth: 0.8)
                    .frame(width: 76, height: 76)
                Circle()
                    .stroke(dotColor.opacity(0.4 + level * 0.6), lineWidth: 2)
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .modifier(PulseIfRecordingOrb(state: state))
            }
            .frame(width: 92, height: 92)
            .background(DS.Color.paper, in: Circle())
            .overlay(Circle().stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
            .dsShadowPop()
            Text(formatted)
                .font(DS.Font.mono(10))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
        }
        .contentShape(Circle())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecordingOrb: ViewModifier {
    let state: PipelineState
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing && isRecording ? 0.55 : 1)
            .scaleEffect(pulsing && isRecording ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
}

#Preview {
    VStack(spacing: 20) {
        IndicatorOrb(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorOrb(state: .processing)
        IndicatorOrb(state: .refining)
        IndicatorOrb(state: .error(message: "erro"))
    }
    .padding(40)
    .background(DS.Color.paper2)
}
