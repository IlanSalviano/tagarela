import Foundation
import OSLog

@MainActor
final class ToastCenter: ObservableObject {
    private let logger = Logger(subsystem: "com.tagarela", category: "ToastCenter")
    /// Único toast visível por vez. Overflow substitui o atual.
    @Published private(set) var current: Toast?

    private var autoDismissTask: Task<Void, Never>?
    /// Tempo padrão antes do auto-dismiss (4s).
    static let autoDismissNanoseconds: UInt64 = 4_000_000_000

    /// Mostra um novo toast, cancelando timer anterior se houver.
    func show(_ toast: Toast) {
        autoDismissTask?.cancel()
        current = toast
        let id = toast.id
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.autoDismissNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.dismissIfStill(id: id)
        }
    }

    /// Dismiss imediato (click no toast ou substituição manual).
    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        current = nil
    }

    /// Dismiss apenas se o id atual ainda for o mesmo (evita dismissar um
    /// toast novo agendado durante o sleep).
    private func dismissIfStill(id: UUID) {
        guard current?.id == id else { return }
        current = nil
        autoDismissTask = nil
    }

    deinit {
        autoDismissTask?.cancel()
    }
}
