import Foundation

struct TranscriptionInput: Sendable {
    let durationSeconds: Double
    let rawText: String
    let refinedText: String
    let refinerKind: String
    let llmModelName: String?
    let whisperModelName: String
    let styleName: String
    let frontmostAppBundleID: String?
}

protocol HistoryStore: Sendable {
    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws
    func recent(limit: Int) async throws -> [Transcription]
}
