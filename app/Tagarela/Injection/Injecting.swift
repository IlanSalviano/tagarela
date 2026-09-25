import Foundation

protocol Injecting: AnyObject, Sendable {
    /// Injeta texto no app em foco via clipboard + ⌘V.
    /// Retorna o bundle ID do app que estava em foco no momento da injeção.
    @discardableResult
    func inject(text: String) async throws -> String?

    /// App em foco agora. Lido **antes** da cola para que o histórico possa ser
    /// salvo primeiro: se a cola falhar, o ditado não se perde (S3 da auditoria).
    func frontmostBundleID() async -> String?
}

extension Injecting {
    func frontmostBundleID() async -> String? { nil }
}

enum InjectionError: Error, Equatable {
    case accessibilityDenied
    case pasteboardWriteFailed
}
