import Foundation
import OSLog

final class OpenAIRefiner: TextRefiner, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "OpenAIRefiner")
    private let session: URLSession
    private let keychain: KeychainService
    private let model: String
    private let timeoutSec: TimeInterval
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    init(session: URLSession, keychain: KeychainService, model: String, timeoutSec: TimeInterval) {
        self.session = session
        self.keychain = keychain
        self.model = model
        self.timeoutSec = timeoutSec
    }

    var kind: RefinerKind { .openai }

    func refine(_ rawText: String, style: Style) async throws -> String {
        guard let key = try keychain.openAIKey(), !key.isEmpty else {
            throw RefinerError.unauthorized
        }
        let systemTokens = TokenCounter.estimate(style.systemPrompt)
        let textToSend: String
        if let truncated = BaseRemoteRefiner.truncatedIfNeeded(rawText, modelName: model, systemTokens: systemTokens) {
            textToSend = truncated
        } else {
            textToSend = rawText
        }
        do {
            return try await chat(rawText: textToSend, style: style, key: key)
        } catch RefinerError.contextExceeded {
            logger.info("contextExceeded, retry with hard truncation")
            // se já vinha truncado, força um truncamento mais agressivo
            let chars = Array(textToSend)
            let cut = chars.count * 3 / 10  // 30% cada ponta agora
            let hard = String(chars[0..<cut]) + BaseRemoteRefiner.truncationMarker + String(chars[(chars.count-cut)..<chars.count])
            return try await chat(rawText: hard, style: style, key: key)
        }
    }

    private func chat(rawText: String, style: Style, key: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeoutSec
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": style.systemPrompt],
                ["role": "user",   "content": rawText],
            ],
            "temperature": 0.3,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw RefinerError.malformedResponse }
            if http.statusCode != 200 {
                throw RefinerErrorMapper.from(httpStatus: http.statusCode, body: data)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
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
