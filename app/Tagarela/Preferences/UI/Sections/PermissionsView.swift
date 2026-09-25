import SwiftUI

/// Preferências › Permissões: as três permissões do macOS, o estado ao vivo de
/// cada uma e um botão que leva a um lugar onde dá para resolver.
///
/// Até aqui, depois do onboarding não existia lugar nenhum no app para isso, e
/// os avisos mandavam o usuário "abrir as Preferências" — onde não havia nada.
struct PermissionsView: View {
    let service: PermissionService
    @State private var snapshot: PermissionsSnapshot

    init(service: PermissionService) {
        self.service = service
        _snapshot = State(initialValue: service.snapshot())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "preferences.section.permissoes", defaultValue: "Permissões"))
                    .font(DS.Font.display(22))
                Text(String(localized: "permissions.intro",
                            defaultValue: "O tagarela precisa de três permissões do macOS. Sem qualquer uma delas, uma parte do ditado para de funcionar."))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    row(.microphone)
                    Divider()
                    row(.inputMonitoring)
                    Divider()
                    row(.accessibility)
                }

                Text(String(localized: "permissions.footer",
                            defaultValue: "O estado aqui atualiza sozinho quando você concede algo nos Ajustes."))
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.ink3)
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .task {
            // Um stream próprio — `makeSnapshots()` é multicast desde a Fase 5.
            // A Task é cancelada quando a seção some, o que encerra o stream.
            for await next in service.makeSnapshots() { snapshot = next }
        }
    }

    // MARK: - linha

    private func row(_ kind: PermissionKind) -> some View {
        let status = status(of: kind)
        let action = PermissionAction.for(kind, status: status)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: status == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(status == .granted ? DS.Color.moss : DS.Color.carmine)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title(of: kind))
                        .font(DS.Font.mono(13, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                    Text(label(of: status))
                        .font(DS.Font.mono(10))
                        .foregroundStyle(status == .granted ? DS.Color.moss : DS.Color.carmine)
                }
                Text(purpose(of: kind))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if kind == .accessibility {
                    Text(String(localized: "permissions.accessibility.hint",
                                defaultValue: "Nos Ajustes do macOS 27 ela pode aparecer como “Device Control and Data Access”."))
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if action != .none {
                Button(action: { perform(action, for: kind) }) {
                    Text(buttonTitle(for: action))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(DS.Color.carmine, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func perform(_ action: PermissionAction, for kind: PermissionKind) {
        switch (action, kind) {
        case (.none, _):
            break
        case (.request, _), (.requestAndOpenSettings, .microphone):
            Task { _ = await service.requestMicrophone() }
        case (.requestAndOpenSettings, .accessibility):
            service.requestAccessibility()
            service.openAccessibilitySettings()
        case (.requestAndOpenSettings, .inputMonitoring):
            service.requestInputMonitoring()
            service.openInputMonitoringSettings()
        case (.openSettings, .microphone):
            service.openMicrophoneSettings()
        case (.openSettings, .accessibility):
            service.openAccessibilitySettings()
        case (.openSettings, .inputMonitoring):
            service.openInputMonitoringSettings()
        }
    }

    // MARK: - textos

    private func status(of kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .microphone:      return snapshot.microphone
        case .inputMonitoring: return snapshot.inputMonitoring
        case .accessibility:   return snapshot.accessibility
        }
    }

    private func title(of kind: PermissionKind) -> String {
        switch kind {
        case .microphone:
            return String(localized: "permissions.microphone.title", defaultValue: "Microfone")
        case .inputMonitoring:
            return String(localized: "permissions.inputMonitoring.title", defaultValue: "Monitoramento de Entrada")
        case .accessibility:
            return String(localized: "permissions.accessibility.title", defaultValue: "Acessibilidade")
        }
    }

    private func purpose(of kind: PermissionKind) -> String {
        switch kind {
        case .microphone:
            return String(localized: "permissions.microphone.purpose",
                          defaultValue: "Pra ouvir o que você dita. O áudio nunca é salvo.")
        case .inputMonitoring:
            return String(localized: "permissions.inputMonitoring.purpose",
                          defaultValue: "Pra perceber a tecla ⌥ direito com qualquer app em primeiro plano. Sem ela, o atalho não funciona.")
        case .accessibility:
            return String(localized: "permissions.accessibility.purpose",
                          defaultValue: "Pra colar o texto onde está o cursor (⌘V). Sem ela, o ditado fica só no clipboard e no histórico.")
        }
    }

    private func label(of status: PermissionStatus) -> String {
        switch status {
        case .granted: return String(localized: "permissions.status.granted", defaultValue: "concedida")
        case .denied:  return String(localized: "permissions.status.denied", defaultValue: "negada")
        case .needed, .unknown:
            return String(localized: "permissions.status.needed", defaultValue: "falta conceder")
        }
    }

    private func buttonTitle(for action: PermissionAction) -> String {
        switch action {
        case .none: return ""
        case .request:
            return String(localized: "permissions.action.request", defaultValue: "Pedir acesso")
        case .requestAndOpenSettings:
            return String(localized: "permissions.action.grant", defaultValue: "Conceder…")
        case .openSettings:
            return String(localized: "permissions.action.openSettings", defaultValue: "Abrir Ajustes")
        }
    }
}
