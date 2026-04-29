import Foundation
import SwiftData

@Model
final class Transcription {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var durationSeconds: Double
    var rawText: String
    var refinedText: String
    var refinerKind: String        // "openai" | "ollama" | "none"
    var llmModelName: String?
    var whisperModelName: String
    var styleName: String
    var frontmostAppBundleID: String?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         durationSeconds: Double,
         rawText: String,
         refinedText: String,
         refinerKind: String,
         llmModelName: String?,
         whisperModelName: String,
         styleName: String,
         frontmostAppBundleID: String?) {
        self.id = id
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.rawText = rawText
        self.refinedText = refinedText
        self.refinerKind = refinerKind
        self.llmModelName = llmModelName
        self.whisperModelName = whisperModelName
        self.styleName = styleName
        self.frontmostAppBundleID = frontmostAppBundleID
    }
}
