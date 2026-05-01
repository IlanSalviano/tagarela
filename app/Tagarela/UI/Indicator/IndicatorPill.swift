import SwiftUI

struct IndicatorPill: View, IndicatorView {
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
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .modifier(PulseIfRecording(state: state))
            WaveBars(level: level,
                     color: state == .idle ? DS.Color.ink3 : DS.Color.ink,
                     count: 16, height: 22, width: 84)
            Text(formatted)
                .font(DS.Font.mono(11))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
                .frame(minWidth: 38)
            Rectangle()
                .fill(DS.Color.hairline)
                .frame(width: 1, height: 16)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.Color.ink3)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.Color.paper, in: Capsule())
        .overlay(Capsule().stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
        .contentShape(Capsule())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecording: ViewModifier {
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
        IndicatorPill(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorPill(state: .processing)
        IndicatorPill(state: .refining)
        IndicatorPill(state: .error(message: "erro"))
    }
    .padding(40)
    .background(LinearGradient(colors: [DS.Color.paper2, DS.Color.paper],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing))
}
