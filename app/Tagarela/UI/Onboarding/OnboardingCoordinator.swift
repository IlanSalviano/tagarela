import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
    enum Step { case welcome, perms, model }

    @Published var step: Step = .welcome
    @Published var permsSnapshot: PermissionsSnapshot
    @Published var modelDownloadProgress: Double = 0
    @Published var modelLoaded: Bool = false

    let permissionService: PermissionService
    let transcriber: Transcribing

    init(permissionService: PermissionService, transcriber: Transcribing) {
        self.permissionService = permissionService
        self.transcriber = transcriber
        self.permsSnapshot = permissionService.snapshot()
        Task { [weak self] in
            guard let self else { return }
            for await snap in self.permissionService.snapshots {
                await MainActor.run { self.permsSnapshot = snap }
            }
        }
    }

    func advance() {
        switch step {
        case .welcome: step = .perms
        case .perms: step = .model
        case .model: break
        }
    }

    func back() {
        switch step {
        case .welcome: break
        case .perms: step = .welcome
        case .model: step = .perms
        }
    }

    func loadModel(_ name: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriber.loadModel(name) { [weak self] p in
                    Task { @MainActor in self?.modelDownloadProgress = p }
                }
                await MainActor.run { self.modelLoaded = true }
            } catch {
                // erro de download fica no log; UI fica travada em "baixando".
                // Tratamento real vem na Fase 2.
            }
        }
    }
}
