import Foundation

struct Style: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let systemPrompt: String
    let preserveOrality: Bool
    let isBuiltIn: Bool
}
