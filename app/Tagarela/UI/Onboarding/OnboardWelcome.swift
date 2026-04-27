import SwiftUI

struct OnboardWelcome: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 48).padding(.bottom, 32)
            Text("ditado por voz para qualquer coisa que você escreva.")
                .font(DS.Font.display(32))
                .foregroundStyle(DS.Color.ink)
                .padding(.bottom, 16)
            Text("aperte ⌥ direito em qualquer app, fale, aperte de novo. o texto refinado aparece onde estiver o cursor. funciona offline. fala português.")
                .font(DS.Font.ui(14))
                .foregroundStyle(DS.Color.ink2)
                .lineSpacing(4)
                .frame(maxWidth: 460, alignment: .leading)
            Spacer()
            HStack {
                Spacer()
                Button(action: onContinue) {
                    Text("continuar →")
                        .font(DS.Font.mono(12))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Text("PASSO 1 / 3").font(DS.Font.mono(9)).tracking(1)
                Text("·")
                Text("BOAS-VINDAS").font(DS.Font.mono(9)).tracking(1)
            }
            .foregroundStyle(DS.Color.ink3)
            .padding(.top, 16)
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 48)
        .frame(width: 560, height: 400)
        .background(DS.Color.paper)
    }
}
