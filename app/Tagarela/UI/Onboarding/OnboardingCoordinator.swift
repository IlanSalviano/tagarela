import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
    enum Step { case welcome, perms, model }

    @Published var step: Step = .welcome
    @Published var permsSnapshot: PermissionsSnapshot
    @Published var modelDownloadProgress: Double = 0
    @Published var modelLoaded: Bool = false
    @Published var modelLoadError: String?
    @Published var selectedModel: String = WhisperModelCatalog.all.first(where: { $0.recommended })?.name
                                          ?? "large-v3-turbo"

    let permissionService: PermissionService
    let transcriber: Transcribing
    private let prefs: PreferencesStore

    init(permissionService: PermissionService,
         transcriber: Transcribing,
         prefs: PreferencesStore) {
        self.permissionService = permissionService
        self.transcriber = transcriber
        self.prefs = prefs
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

    func loadSelectedModel() {
        modelLoaded = false
        modelDownloadProgress = 0
        modelLoadError = nil
        let name = selectedModel
        Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriber.loadModel(name) { [weak self] p in
                    Task { @MainActor in self?.modelDownloadProgress = p }
                }
                await MainActor.run {
                    self.modelLoaded = true
                    self.prefs.whisperModelName = name
                }
            } catch {
                await MainActor.run {
                    self.modelLoadError = String(describing: error)
                }
            }
        }
    }
}
