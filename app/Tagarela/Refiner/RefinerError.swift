import Foundation

enum RefinerError: Error, Equatable, Sendable {
    case networkOffline
    case unauthorized
    case timedOut
    case serverError(Int)
    case rateLimited
    case contextExceeded
    case modelNotFound(String)
    case malformedResponse
    case cancelled
}
