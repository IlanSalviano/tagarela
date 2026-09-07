import Foundation

/// Ping ao Ollama com cache curto.
///
/// A `baseURL` era fixada no init e nunca atualizada: apontar o Ollama para
/// outra máquina em Preferências deixava o ping no `localhost` antigo, e todo
/// `refine` virava "Sem rede — usando texto cru" até relançar o app
/// (auditoria §5.4). Agora a URL vem por chamada e o cache é por URL.
actor OllamaHealthChecker {
    private let session: URLSession
    private let defaultBaseURL: URL
    private let positiveTTL: TimeInterval = 30
    /// TTL negativo curto: um "não" fica caro quando o servidor volta logo em
    /// seguida — e 30 s de texto cru é uma eternidade em uso real.
    private let negativeTTL: TimeInterval = 3
    private var cache: [URL: (timestamp: Date, ok: Bool)] = [:]

    init(session: URLSession, baseURL: URL) {
        self.session = session
        self.defaultBaseURL = baseURL
    }

    /// Invalida cache. Chamar quando refinerKind ou ollamaBaseURL mudar.
    func invalidate() { cache.removeAll() }

    func isAvailable() async -> Bool {
        await isAvailable(baseURL: defaultBaseURL)
    }

    func isAvailable(baseURL: URL) async -> Bool {
        if let last = cache[baseURL] {
            let ttl = last.ok ? positiveTTL : negativeTTL
            if Date().timeIntervalSince(last.timestamp) < ttl { return last.ok }
        }
        let result = await ping(baseURL: baseURL)
        switch result {
        case .reachable:
            cache[baseURL] = (Date(), true)
            return true
        case .unreachable:
            cache[baseURL] = (Date(), false)
            return false
        case .cancelled:
            // Não cacheia: um Esc durante `.refining` com ping em vôo derrubava
            // os 30 s seguintes para texto cru, com o Ollama no ar o tempo todo.
            return false
        }
    }

    private enum PingResult { case reachable, unreachable, cancelled }

    private func ping(baseURL: URL) async -> PingResult {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 2
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200 ? .reachable : .unreachable
        } catch is CancellationError {
            return .cancelled
        } catch let error as URLError where error.code == .cancelled {
            return .cancelled
        } catch {
            return Task.isCancelled ? .cancelled : .unreachable
        }
    }
}
