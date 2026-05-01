import Foundation

protocol Transcribing: AnyObject, Sendable {
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws
    func transcribe(buffer: AudioBuffer,
                    language: String,
                    initialPrompt: String?) async throws -> String
    func unloadModel()
    var loadedModelName: String? { get }
}

enum TranscribeError: Error, Equatable {
    case modelNotLoaded
    case modelDownloadFailed(String)
    case transcriptionFailed(String)
    case bufferTooShort
}
