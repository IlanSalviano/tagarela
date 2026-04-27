import Foundation

enum PipelineEvent: Equatable, Sendable {
    case toggle
    case cancel
    case stateChanged(PipelineState)
    case finished(rawText: String, refinedText: String, frontmostApp: String?)
    case errorOccurred(String)
}
