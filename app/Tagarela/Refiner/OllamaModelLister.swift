import Foundation

enum OllamaModelListerError: Error, Equatable {
    case offline
    case malformedResponse
}

actor OllamaModelLister {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Lista nomes de modelos pulled localmente via GET /api/tags.
    /// Sem cache — refresh é responsabilidade do caller.
    func availableModels() async throws -> [String] {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 4
        req.httpMethod = "GET"
        let data: Data
        do {
            (data, _) = try await session.data(for: req)
        } catch {
            throw OllamaModelListerError.offline
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["models"] as? [[String: Any]]
        else { throw OllamaModelListerError.malformedResponse }
        return arr.compactMap { $0["name"] as? String }
    }
}
