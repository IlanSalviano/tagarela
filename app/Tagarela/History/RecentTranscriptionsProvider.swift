import Foundation
import OSLog

@MainActor
final class RecentTranscriptionsProvider: ObservableObject {
    private let logger = Logger(subsystem: "com.tagarela", category: "RecentTranscriptions")
    private let store: HistoryStore
    private let limit: Int

    @Published private(set) var recents: [Transcription] = []

    init(store: HistoryStore, limit: Int = 5) {
        self.store = store
        self.limit = limit
    }

    func reload() async {
        do {
            recents = try await store.recent(limit: limit)
        } catch {
            logger.error("recent failed: \(String(describing: error), privacy: .public)")
            recents = []
        }
    }
}
