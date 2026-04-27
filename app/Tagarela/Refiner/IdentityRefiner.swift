import Foundation

final class IdentityRefiner: TextRefiner, Sendable {
    let kind: RefinerKind = .none
    func refine(_ raw: String, style: String) async throws -> String { raw }
}
