import SwiftUI

struct SwapErrorSheet: View {
    let target: String
    let errorMessage: String
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "preferences.transcription.swap.error.title",
                         defaultValue: "Falha ao trocar"))
                .font(DS.Font.display(20))
                .foregroundStyle(DS.Color.ink)
            Text(String(localized: "preferences.transcription.swap.error.body",
                         defaultValue: "Não consegui mudar pra \(target).\n\n\(errorMessage)"))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(String(localized: "preferences.transcription.swap.error.close",
                              defaultValue: "Fechar")) { onClose() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
                Button(action: onRetry) {
                    Text(String(localized: "preferences.transcription.swap.error.retry",
                                 defaultValue: "Tentar de novo"))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(DS.Color.paper)
    }
}
