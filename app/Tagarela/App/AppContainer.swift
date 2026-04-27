import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let appState = AppState()
    // Serviços vão sendo injetados nas tasks 11+. Por enquanto vazio.

    init() {}
}
