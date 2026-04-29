import SwiftUI

struct StateRow: View {
    let state: PipelineState

    private var sub: String {
        switch state {
        case .idle:
            return String(localized: "pipeline.sub.idle", defaultValue: "right ⌥ pra começar")
        case .recording(let s, _):
            return String(format: "%02d:%02d · 16 kHz mono", Int(s) / 60, Int(s) % 60)
        case .processing:
            return String(localized: "pipeline.sub.processing", defaultValue: "whisper large-v3")
        case .refining:
            return String(localized: "pipeline.sub.refining", defaultValue: "identity (sem llm)")
        case .error:
            return String(localized: "pipeline.sub.error", defaultValue: "fallback: texto cru")
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(state.dotColorName))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.label)
                    .font(DS.Font.mono(13))
                    .foregroundStyle(DS.Color.ink)
                Text(sub)
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.ink3)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
