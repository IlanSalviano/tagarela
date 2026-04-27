import Foundation

actor OllamaHealthChecker {
    private let session: URLSession
    private let baseURL: URL
    private let cacheTTL: TimeInterval = 30
    private var lastCheck: (timestamp: Date, ok: Bool)?

    init(session: URLSession, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Invalida cache. Chamar quando refinerKind ou ollamaBaseURL mudar.
    func invalidate() { lastCheck = nil }

    func isAvailable() async -> Bool {
        if let last = lastCheck, Date().timeIntervalSince(last.timestamp) < cacheTTL {
            return last.ok
        }
        let ok = await ping()
        lastCheck = (Date(), ok)
        return ok
    }

    private func ping() async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 2
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
