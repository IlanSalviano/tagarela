import SwiftUI

struct OnboardPerms: View {
    let snapshot: PermissionsSnapshot
    var onMicTap: () -> Void
    var onAccessibilityTap: () -> Void
    var onInputMonitoringTap: () -> Void
    var onContinue: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PASSO 2 / 3")
                    .font(DS.Font.mono(9)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                Text("três permissões.")
                    .font(DS.Font.display(26)).foregroundStyle(DS.Color.ink)
                Text("o macOS exige isso pra app capturar áudio e atalhos globais. nada vai pra fora da máquina.")
                    .font(DS.Font.ui(12)).foregroundStyle(DS.Color.ink2)
            }
            VStack(spacing: 10) {
                permCard(name: "microfone",
                         status: snapshot.microphone,
                         why: "captura sua voz pra transcrever. áudio nunca é salvo, só processado em memória.",
                         onTap: onMicTap)
                permCard(name: "acessibilidade",
                         status: snapshot.accessibility,
                         why: "necessário pra registrar o atalho global e simular ⌘V no app de destino.",
                         onTap: onAccessibilityTap)
                permCard(name: "input monitoring",
                         status: snapshot.inputMonitoring,
                         why: "pra ouvir a tecla ⌥ direito mesmo quando outro app está em foco.",
                         onTap: onInputMonitoringTap)
            }
            Spacer()
            HStack {
                Spacer()
                Button(action: onBack) {
                    Text("← voltar")
                        .font(DS.Font.mono(12))
                        .foregroundStyle(DS.Color.ink3)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(DS.Color.paper2, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
                Button(action: onContinue) {
                    Text("continuar →")
                        .font(DS.Font.mono(12))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .frame(width: 560, height: 520)
        .background(DS.Color.paper)
    }

    @ViewBuilder
    private func permCard(name: String,
                          status: PermissionStatus,
                          why: String,
                          onTap: @escaping () -> Void) -> some View {
        let color: Color = {
            switch status {
            case .granted: return DS.Color.moss
            case .denied: return DS.Color.carmine
            default: return DS.Color.ink3
            }
        }()
        let label: String = {
            switch status {
            case .granted: return "concedida"
            case .denied: return "negada"
            default: return "necessária"
            }
        }()
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name)
                    .font(DS.Font.mono(12, weight: .medium))
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                Text(label.uppercased())
                    .font(DS.Font.mono(9))
                    .tracking(1)
                    .foregroundStyle(color)
            }
            Text(why)
                .font(DS.Font.ui(12))
                .foregroundStyle(DS.Color.ink2)
                .lineSpacing(2)
            if status != .granted {
                Button(action: onTap) {
                    Text("abrir configurações")
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(DS.Color.paper2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
    }
}
