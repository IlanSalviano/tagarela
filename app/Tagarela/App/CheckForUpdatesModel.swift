import Combine
import Sparkle

/// Estado do item "Buscar atualizações…" do menu.
///
/// `canCheckForUpdates` fica falso enquanto o Sparkle já está checando: o item
/// desabilita em vez de empilhar checagens — o padrão que a documentação do
/// Sparkle recomenda para esse item.
@MainActor
final class CheckForUpdatesModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private let updater: SPUUpdater
    private var subscription: AnyCancellable?

    init(updater: SPUUpdater) {
        self.updater = updater
        subscription = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.canCheckForUpdates = value }
            }
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
