import Foundation

@MainActor
final class CustomStyleStoreNoop: ObservableObject, CustomStyleStore {
    @Published private(set) var styles: [CustomStyle] = []

    func reload() async { }
    func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle {
        throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
    }
    func update(_ style: CustomStyle) async throws {
        throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
    }
    func delete(_ style: CustomStyle) async throws {
        throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
    }
}
