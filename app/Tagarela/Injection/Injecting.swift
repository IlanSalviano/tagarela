import Foundation

protocol Injecting: AnyObject, Sendable {
    /// Injeta texto no app em foco via clipboard + ⌘V.
    /// Retorna o bundle ID do app que estava em foco no momento da injeção.
    @discardableResult
    func inject(text: String) async throws -> String?
}

enum InjectionError: Error, Equatable {
    case accessibilityDenied
    case pasteboardWriteFailed
}
