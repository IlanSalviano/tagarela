import Foundation

enum RefinerErrorMapper {
    static func from(_ error: Error) -> RefinerError {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost:
                return .networkOffline
            case .timedOut:
                return .timedOut
            case .cancelled:
                return .cancelled
            default:
                return .networkOffline
            }
        }
        if let r = error as? RefinerError { return r }
        return .malformedResponse
    }

    static func from(httpStatus: Int, body: Data) -> RefinerError {
        switch httpStatus {
        case 401: return .unauthorized
        case 404:
            if let s = String(data: body, encoding: .utf8),
               s.lowercased().contains("model") {
                return .modelNotFound(extractModelName(s) ?? "?")
            }
            return .serverError(404)
        case 429: return .rateLimited
        case 400:
            if let s = String(data: body, encoding: .utf8)?.lowercased(),
               s.contains("context_length") || s.contains("context window") {
                return .contextExceeded
            }
            return .serverError(400)
        case 500...599: return .serverError(httpStatus)
        default: return .serverError(httpStatus)
        }
    }

    private static func extractModelName(_ body: String) -> String? {
        // Matches: model followed by quoted token (handles both escaped and unescaped quotes).
        // Pattern: 'model' + optional space + optional backslash + quote + name + optional backslash + quote
        let patterns = [
            // Escaped quotes: model \"name\"
            try? NSRegularExpression(pattern: "model\\s+\\\\\"([A-Za-z0-9._:\\-]{1,63})\\\\\"", options: []),
            // Unescaped quotes: model "name"
            try? NSRegularExpression(pattern: "model\\s+\"([A-Za-z0-9._:\\-]{1,63})\"", options: [])
        ]

        let nsBody = body as NSString
        for pattern in patterns.compactMap({ $0 }) {
            if let match = pattern.firstMatch(in: body, options: [], range: NSRange(location: 0, length: nsBody.length)),
               let range = Range(match.range(at: 1), in: body) {
                return String(body[range])
            }
        }
        return nil
    }
}
