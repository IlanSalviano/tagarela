import Foundation
import OSLog

/// Fallback usado quando o ModelContainer falha ao abrir.
final class HistoryStoreNoop: HistoryStore {
    private let logger = Logger(subsystem: "com.tagarela", category: "History")

    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {
        logger.error("HistoryStoreNoop: ignorando save — container indisponível")
    }

    func recent(limit: Int) async throws -> [Transcription] { [] }
}
