import SwiftUI

/// Variação D — HUD style Siri (260×80). Background semi-transparente escuro,
/// dot pulsante carmim, waveform horizontal grande, timer + label.
/// Per ADR-0001, dark only — em light mode pode ficar baixo contraste (aceito).
struct IndicatorHUD: View, IndicatorView {
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
        case .idle: return Color.white.opacity(0.6)
        }
    }

    private var stateLabel: String {
        switch state {
        case .recording: return "rec"
        case .processing: return "trans"
        case .refining: return "refn"
        case .error: return "err"
        case .idle: return "idle"
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(dotColor.opacity(0.4), lineWidth: 1)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .modifier(PulseIfRecordingHUD(state: state))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stateLabel)
                    .font(DS.Font.mono(9))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                WaveBars(level: level,
                         color: .white,
                         count: 20, height: 26, width: 130)
            }
            Spacer(minLength: 0)
            Text(formatted)
                .font(DS.Font.mono(13))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 300, height: 80)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecordingHUD: ViewModifier {
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
        IndicatorHUD(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorHUD(state: .processing)
        IndicatorHUD(state: .refining)
        IndicatorHUD(state: .error(message: "erro"))
    }
    .padding(40)
    .background(LinearGradient(colors: [.gray.opacity(0.3), .black], startPoint: .top, endPoint: .bottom))
}
