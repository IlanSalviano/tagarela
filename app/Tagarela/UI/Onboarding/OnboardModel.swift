import SwiftUI

struct OnboardModel: View {
    let downloadProgress: Double
    let loaded: Bool
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
                modelRow(name: "large-v3", size: "2.9 GB", ram: "≥ 16 GB",
                         recommended: true, selected: true)
                modelRow(name: "medium", size: "1.4 GB", ram: "≥ 8 GB",
                         recommended: false, selected: false)
                modelRow(name: "small", size: "466 MB", ram: "≥ 4 GB",
                         recommended: false, selected: false)
                if !loaded && downloadProgress > 0 {
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

    @ViewBuilder
    private func modelRow(name: String,
                          size: String,
                          ram: String,
                          recommended: Bool,
                          selected: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .stroke(DS.Color.ink, lineWidth: 1.2)
                .background(selected ? Circle().fill(DS.Color.ink).padding(3) : nil)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DS.Font.mono(12, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                Text("\(size) · \(ram) RAM")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.ink3)
            }
            Spacer()
            if recommended {
                Text(String(localized: "onboarding.model.badge.recommended", defaultValue: "RECOM."))
                    .font(DS.Font.mono(9))
                    .tracking(1)
                    .foregroundStyle(DS.Color.carmine)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(DS.Color.carmine, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(selected ? DS.Color.paper2 : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(selected ? DS.Color.ink : DS.Color.hairlineStrong, lineWidth: 0.5))
    }
}
