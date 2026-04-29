import Foundation
import OSLog

final class OllamaRefiner: TextRefiner, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "OllamaRefiner")
    private let session: URLSession
    private let baseURL: URL
    private let model: String
    private let timeoutSec: TimeInterval
    private let healthChecker: OllamaHealthChecker

    init(session: URLSession,
         baseURL: URL,
         model: String,
         timeoutSec: TimeInterval,
         healthChecker: OllamaHealthChecker) {
        self.session = session
        self.baseURL = baseURL
        self.model = model
        self.timeoutSec = timeoutSec
        self.healthChecker = healthChecker
    }

    var kind: RefinerKind { .ollama }

    func refine(_ rawText: String, style: Style) async throws -> String {
        guard await healthChecker.isAvailable() else {
            throw RefinerError.networkOffline
        }
        let systemTokens = TokenCounter.estimate(style.systemPrompt)
        let textToSend = BaseRemoteRefiner.truncatedIfNeeded(rawText, modelName: model, systemTokens: systemTokens) ?? rawText
        do {
            return try await chat(rawText: textToSend, style: style)
        } catch RefinerError.contextExceeded {
            logger.info("contextExceeded, retry with hard truncation")
            let chars = Array(textToSend)
            let cut = chars.count * 3 / 10
            let hard = String(chars[0..<cut]) + BaseRemoteRefiner.truncationMarker + String(chars[(chars.count-cut)..<chars.count])
            return try await chat(rawText: hard, style: style)
        }
    }

    private func chat(rawText: String, style: Style) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeoutSec
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": style.systemPrompt],
                ["role": "user",   "content": rawText],
            ],
            "options": ["temperature": 0.3],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw RefinerError.malformedResponse }
            if http.statusCode != 200 {
                throw RefinerErrorMapper.from(httpStatus: http.statusCode, body: data)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? String
            else { throw RefinerError.malformedResponse }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let e as RefinerError {
            throw e
        } catch {
            throw RefinerErrorMapper.from(error)
        }
    }
}
