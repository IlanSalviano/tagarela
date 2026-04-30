import Foundation

struct Toast: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ToastKind
    let createdAt: Date

    init(kind: ToastKind, id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
    }
}
