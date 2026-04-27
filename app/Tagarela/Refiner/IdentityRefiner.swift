import Foundation

final class IdentityRefiner: TextRefiner, Sendable {
    let kind: RefinerKind = .none
    func refine(_ raw: String, style: Style) async throws -> String { raw }
}
