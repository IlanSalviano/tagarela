import Foundation
import OSLog

/// Fachada de diagnóstico. Cada linha vai para o log unificado e, quando
/// `.notice`/`.error`, também para o arquivo rotativo do `DiagnosticsLog` —
/// que é o único que sobrevive aos dias entre a falha e a investigação.
///
/// **Regra de privacidade (não negociável):** nunca passe por aqui o texto
/// ditado, o conteúdo do clipboard ou a API key. Só contagens, durações,
/// formatos, métricas numéricas e bundle id do app-alvo.
/// `DiagnosticsLogTests.test_noDictatedTextInSources` quebra a suíte se isso
/// for violado.
enum Diag {
    enum Category: String, CaseIterable {
        case audio, pipeline, transcribe, hotkey, inject, permissions, app, health

        /// Casa com as categorias que os `Logger` existentes já usavam, pra que
        /// os predicados de `/usr/bin/log` da auditoria continuem valendo.
        var osLogCategory: String {
            switch self {
            case .audio:       return "Audio"
            case .pipeline:    return "Pipeline"
            case .transcribe:  return "Transcribe"
            case .hotkey:      return "Hotkey"
            case .inject:      return "Inject"
            case .permissions: return "Permissions"
            case .app:         return "App"
            case .health:      return "Health"
            }
        }
    }

    /// Marco normal do pipeline. Persiste no arquivo.
    static func notice(_ category: Category, _ message: String) {
        logger(for: category).notice("\(message, privacy: .public)")
        DiagnosticsLog.shared.append(level: "notice", category: category.rawValue, message: message)
    }

    /// Anomalia que explica um "não fez o STT". Persiste no arquivo.
    static func error(_ category: Category, _ message: String) {
        logger(for: category).error("\(message, privacy: .public)")
        DiagnosticsLog.shared.append(level: "error", category: category.rawValue, message: message)
    }

    /// Detalhe de depuração. **Não** vai para o arquivo — e no log unificado
    /// praticamente não persiste (auditoria §3.2). Use para ruído de bancada.
    static func info(_ category: Category, _ message: String) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    private static let loggers: [Category: Logger] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map {
            ($0, Logger(subsystem: "com.tagarela", category: $0.osLogCategory))
        })

    private static func logger(for category: Category) -> Logger {
        loggers[category] ?? Logger(subsystem: "com.tagarela", category: category.osLogCategory)
    }
}
