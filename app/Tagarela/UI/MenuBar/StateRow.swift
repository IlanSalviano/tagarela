import SwiftUI

struct StateRow: View {
    let state: PipelineState
    /// Observado pelo pai (`MenuBarContent`); aqui é só leitura para render.
    var health: PipelineHealth?
    /// Nome do modelo Whisper realmente carregado — o sub-label dizia
    /// "whisper large-v3" fixo, mentindo desde que o modelo virou configurável.
    var loadedModelName: String?
    /// Refinador realmente selecionado — o sub-label dizia "identity (sem llm)",
    /// que é justamente o caso em que `.refining` nem acontece.
    var refinerLabel: String?
    /// `AppState.permissionsAllGranted` existia e **não tinha leitor nenhum**
    /// (auditoria §5.2). Agora vira aviso: sem Acessibilidade a cola morre, sem
    /// Input Monitoring a hotkey morre — e as duas falham em silêncio.
    var permissionsPending: Bool = false
    /// Abre Preferências › Permissões. O aviso era só texto, mandando "abrir as
    /// Preferências" — onde não havia nada sobre permissões.
    var onResolvePermissions: () -> Void = {}
    /// Modelo ainda carregando. `AppState.whisperModelReady` existia desde a
    /// Fase 1 sem escritor nem leitor (auditoria §5.3) — era por isso que o
    /// menu dizia "pronto" enquanto o app ainda não conseguia transcrever nada.
    var modelLoading: Bool = false

    private var sub: String {
        switch state {
        case .idle:
            if modelLoading {
                return String(localized: "pipeline.sub.modelLoading",
                              defaultValue: "carregando o modelo…")
            }
            return String(localized: "pipeline.sub.idle", defaultValue: "⌥ direito pra começar")
        case .recording(let seconds, _):
            return String(format: "%02d:%02d · 16 kHz mono", Int(seconds) / 60, Int(seconds) % 60)
        case .processing:
            return loadedModelName
                ?? String(localized: "pipeline.sub.processing.unloaded",
                          defaultValue: "modelo não carregado")
        case .refining:
            return refinerLabel
                ?? String(localized: "pipeline.sub.refining.unknown", defaultValue: "refinador")
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
                // Só aparece depois do primeiro ditado da sessão: numa sessão
                // recém-aberta a linha não diria nada.
                if let health, health.recordings > 0 {
                    Text(health.summaryLine)
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                }
                if permissionsPending {
                    Button(action: onResolvePermissions) {
                        Text(String(localized: "menubar.permissions.pending",
                                    defaultValue: "permissões pendentes — resolver…"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.carmine)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
