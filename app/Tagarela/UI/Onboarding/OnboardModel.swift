import SwiftUI

struct OnboardModel: View {
    @Binding var selected: String
    let downloadProgress: Double
    let loaded: Bool
    let errorMessage: String?
    var onRetry: () -> Void
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "onboarding.step3.label", defaultValue: "PASSO 3 / 3"))
                    .font(DS.Font.mono(9)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                Text(String(localized: "onboarding.model.headline", defaultValue: "modelos."))
                    .font(DS.Font.display(26)).foregroundStyle(DS.Color.ink)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "onboarding.model.whisper.header", defaultValue: "WHISPER · TRANSCRIÇÃO"))
                    .font(DS.Font.mono(10)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                WhisperModelPicker(selected: $selected, enabled: !loaded)
                if !loaded && downloadProgress > 0 && errorMessage == nil {
                    HStack(spacing: 8) {
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(DS.Color.carmine)
                        Text(String(localized: "onboarding.model.downloading",
                                     defaultValue: "baixando \(Int(downloadProgress * 100))%"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.ink3)
                    }
                }
                if let errorMessage {
                    HStack(spacing: 8) {
                        Text(String(localized: "onboarding.model.error",
                                     defaultValue: "falha: \(errorMessage) · tentar de novo"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.carmineDeep)
                        Button("retry") { onRetry() }
                            .buttonStyle(.plain)
                            .font(DS.Font.mono(10, weight: .medium))
                            .foregroundStyle(DS.Color.carmine)
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button(action: onStart) {
                    Text(String(localized: "onboarding.button.start", defaultValue: "começar →"))
                        .font(DS.Font.mono(12))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(loaded ? DS.Color.ink : DS.Color.ink3,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!loaded)
            }
        }
        .padding(.horizontal, 48).padding(.vertical, 40)
        .frame(width: 560, height: 560)
        .background(DS.Color.paper)
    }
}
