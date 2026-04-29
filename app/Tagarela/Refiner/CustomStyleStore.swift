import Foundation

@MainActor
protocol CustomStyleStore: AnyObject {
    var styles: [CustomStyle] { get }
    func reload() async
    func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle
    func update(_ style: CustomStyle) async throws
    func delete(_ style: CustomStyle) async throws
}

/// Callback chamado pelo store após `delete`, com o UUID do style apagado.
/// O caller (AppContainer) decide se o ID coincidia com `prefs.selectedStyleID`
/// e reseta pra `BuiltInStyles.defaultStyleID` se sim.
typealias OnStyleDeleted = @MainActor (UUID) -> Void

enum CustomStyleStoreError: Error {
    case invalidInput(String)
    case persistenceFailed(Error)
}
