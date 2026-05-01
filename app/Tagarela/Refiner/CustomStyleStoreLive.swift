import Foundation
import SwiftData
import OSLog

@MainActor
final class CustomStyleStoreLive: ObservableObject, CustomStyleStore {
    private let logger = Logger(subsystem: "com.tagarela", category: "CustomStyleStore")
    private let container: ModelContainer
    private let context: ModelContext
    /// Callback pós-delete; recebe o UUID do style apagado pra caller decidir
    /// reset de `prefs.selectedStyleID`.
    private let onStyleDeleted: OnStyleDeleted

    @Published private(set) var styles: [CustomStyle] = []

    init(container: ModelContainer,
         onStyleDeleted: @escaping OnStyleDeleted) {
        self.container = container
        self.context = ModelContext(container)
        self.onStyleDeleted = onStyleDeleted
    }

    func reload() async {
        do {
            let descriptor = FetchDescriptor<CustomStyle>(
                sortBy: [SortDescriptor(\.name, order: .forward)])
            self.styles = try context.fetch(descriptor)
        } catch {
            logger.error("fetch custom styles failed: \(String(describing: error), privacy: .public)")
            self.styles = []
        }
    }

    func create(name: String,
                systemPrompt: String,
                appendCodeSwitching: Bool,
                bypassDiscipline: Bool) async throws -> CustomStyle {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw CustomStyleStoreError.invalidInput("nome vazio") }
        guard !trimmedPrompt.isEmpty else {
            throw CustomStyleStoreError.invalidInput("system prompt vazio")
        }
        let style = CustomStyle(name: trimmedName,
                                 systemPrompt: trimmedPrompt,
                                 appendCodeSwitching: appendCodeSwitching,
                                 bypassDiscipline: bypassDiscipline)
        context.insert(style)
        do {
            try context.save()
        } catch {
            throw CustomStyleStoreError.persistenceFailed(error)
        }
        await reload()
        return style
    }

    func update(_ style: CustomStyle) async throws {
        style.updatedAt = .now
        do {
            try context.save()
        } catch {
            throw CustomStyleStoreError.persistenceFailed(error)
        }
        await reload()
    }

    func delete(_ style: CustomStyle) async throws {
        let deletedID = style.id
        context.delete(style)
        do {
            try context.save()
        } catch {
            throw CustomStyleStoreError.persistenceFailed(error)
        }
        onStyleDeleted(deletedID)
        await reload()
    }
}
