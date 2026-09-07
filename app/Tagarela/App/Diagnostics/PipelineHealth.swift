import Foundation

/// Contadores de saúde desde o launch, para o usuário (e para o próximo
/// investigador) verem em 10 segundos se o app degradou.
///
/// A queixa desta fase é justamente uma degradação silenciosa em sessão longa:
/// sem contadores visíveis, "parou de transcrever" só aparece quando o usuário
/// tenta ditar. Com eles, `vazios`/`curtos`/`recuperações` acima de zero já
/// contam a história antes da pergunta.
@MainActor
final class PipelineHealth: ObservableObject {
    @Published private(set) var recordings = 0
    @Published private(set) var discardedShort = 0
    @Published private(set) var emptyTranscriptions = 0
    @Published private(set) var injectionFailures = 0
    @Published private(set) var recoveries = 0
    /// Vazios em sequência. Duas seguidas disparam a recriação do transcriber.
    @Published private(set) var consecutiveEmpty = 0
    @Published private(set) var lastSuccessAt: Date?

    let launchedAt: Date
    private let clock: () -> Date
    private var wasRecording = false

    init(launchedAt: Date = Date(), clock: @escaping () -> Date = { Date() }) {
        self.launchedAt = launchedAt
        self.clock = clock
    }

    var uptime: TimeInterval { max(0, clock().timeIntervalSince(launchedAt)) }

    var uptimeLabel: String {
        let total = Int(uptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    var summaryLine: String {
        String(localized: "menubar.health.summary",
               defaultValue: "\(recordings) ditados · \(emptyTranscriptions) vazios · \(discardedShort) curtos · \(uptimeLabel)")
    }

    /// Conta uma gravação na **transição** para `.recording`: o estado é
    /// republicado 12–25×/s enquanto grava.
    func noteState(_ state: PipelineState) {
        if case .recording = state {
            if !wasRecording { recordings += 1 }
            wasRecording = true
        } else {
            wasRecording = false
        }
    }

    func noteSuccess() {
        lastSuccessAt = clock()
        consecutiveEmpty = 0
    }

    func noteDiscardedShort() { discardedShort += 1 }

    func noteEmptyTranscription() {
        emptyTranscriptions += 1
        consecutiveEmpty += 1
    }

    func noteInjectionFailure() { injectionFailures += 1 }

    /// Transcriber recriado: a contagem de vazios recomeça, senão o próximo
    /// vazio dispararia recovery imediatamente de novo.
    func noteRecovery() {
        recoveries += 1
        consecutiveEmpty = 0
    }
}
