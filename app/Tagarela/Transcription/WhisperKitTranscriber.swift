import Foundation
import OSLog
import WhisperKit

/// Adaptador do WhisperKit (0.18.x) pro protocolo Transcribing.
///
/// Fluxo de loadModel: usa WhisperKit.download(variant:progressCallback:) pra
/// baixar com progresso, depois inicializa WhisperKit apontando pro modelFolder
/// local. Isso é necessário porque o init com `download: true` não expõe
/// callback de progresso direto.
final class WhisperKitTranscriber: Transcribing, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Transcribe")
    private var pipe: WhisperKit?
    private(set) var loadedModelName: String?

    func loadModel(_ name: String,
                   onProgress: @escaping (Double) -> Void) async throws {
        do {
            let modelFolder = try await WhisperKit.download(variant: name) { progress in
                onProgress(progress.fractionCompleted)
            }
            let config = WhisperKitConfig(modelFolder: modelFolder.path, load: true)
            let pipe = try await WhisperKit(config)
            self.pipe = pipe
            self.loadedModelName = name
            logger.info("loaded whisper model: \(name, privacy: .public)")
        } catch {
            throw TranscribeError.modelDownloadFailed(String(describing: error))
        }
    }

    func transcribe(buffer: AudioBuffer,
                    language: String,
                    initialPrompt: String?) async throws -> String {
        guard let pipe else { throw TranscribeError.modelNotLoaded }
        guard buffer.durationSeconds >= 0.5 else { throw TranscribeError.bufferTooShort }

        let promptTokens: [Int]?
        if ProcessInfo.processInfo.environment["TAGARELA_DISABLE_PROMPT"] == "1" {
            promptTokens = nil
            logger.info("promptTokens desabilitado via env var TAGARELA_DISABLE_PROMPT=1")
        } else if let prompt = initialPrompt, !prompt.isEmpty,
                  let tokenizer = pipe.tokenizer {
            let encoded = tokenizer.encode(text: prompt)
            promptTokens = encoded.isEmpty ? nil : encoded
        } else {
            promptTokens = nil
        }

        let opts = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            usePrefillPrompt: true,
            withoutTimestamps: true,
            promptTokens: promptTokens
        )

        do {
            let results: [TranscriptionResult] = try await pipe.transcribe(
                audioArray: buffer.samples,
                decodeOptions: opts
            )
            let text = results.map(\.text).joined(separator: " ")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw TranscribeError.transcriptionFailed(String(describing: error))
        }
    }
}
