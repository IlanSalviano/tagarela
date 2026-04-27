import Foundation

enum RefinerErrorMapper {
    static func from(_ error: Error) -> RefinerError {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost:
                return .networkOffline
            case .timedOut:
                return .timedOut
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
        // best-effort: procura primeira string com aspas após "model"
        guard let range = body.range(of: "model") else { return nil }
        let tail = body[range.upperBound...]
        let parts = tail.split(separator: "\"")
        for p in parts where !p.isEmpty && p.count < 64 { return String(p) }
        return nil
    }
}
