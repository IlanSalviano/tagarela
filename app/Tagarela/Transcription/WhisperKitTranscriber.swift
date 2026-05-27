import Foundation
import OSLog
import WhisperKit

/// Adaptador do WhisperKit (0.9+) pro protocolo Transcribing.
///
/// Fluxo de loadModel: usa WhisperKit.download(variant:progressCallback:) pra
/// baixar com progresso, depois inicializa WhisperKit apontando pro modelFolder
/// local com prewarm + computeOptions ANE-explícitos.
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
            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                prewarm: true,
                load: true
            )
            let pipe = try await WhisperKit(config)
            self.pipe = pipe
            self.loadedModelName = name
            logger.notice("loaded whisper model: \(name, privacy: .public)")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TranscribeError.modelDownloadFailed(String(describing: error))
        }
    }

    func unloadModel() {
        pipe = nil
        loadedModelName = nil
        logger.notice("unloaded whisper model")
    }

    func transcribe(buffer: AudioBuffer,
                    language: String?,
                    initialPrompt: String?) async throws -> String {
        guard let pipe else { throw TranscribeError.modelNotLoaded }
        guard buffer.durationSeconds >= 0.5 else { throw TranscribeError.bufferTooShort }

        // promptTokens (vocab biasing) está desabilitado: qualquer prompt
        // envenena o prefill, decoder bail e gera só `<|endoftext|>`. Quebra
        // independente de tamanho (72 tokens) e de chunked decode (16s
        // single-chunk). Ver ADR-0005. Param `initialPrompt` mantido no
        // protocolo pra futura reintrodução com fix robusto.
        _ = initialPrompt

        // language == nil → auto-detecção: TranscribeTask só detecta quando
        // detectLanguage == true E language == nil E modelo multilíngue (ADR-0006).
        // Idioma explícito (pt/en) mantém detectLanguage: false → path inalterado.
        let opts = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            usePrefillPrompt: true,
            detectLanguage: language == nil,
            withoutTimestamps: true,
            promptTokens: nil,
            noSpeechThreshold: nil
        )

        do {
            let start = ContinuousClock.now
            let results: [TranscriptionResult] = try await pipe.transcribe(
                audioArray: buffer.samples,
                decodeOptions: opts
            )
            let elapsed = start.duration(to: .now)
            let wallMs = Int(Double(elapsed.components.seconds) * 1000
                             + Double(elapsed.components.attoseconds) / 1e15)
            let audioSec = String(format: "%.1f", buffer.durationSeconds)
            let modelName = self.loadedModelName ?? "?"
            let reqLang = language ?? "auto"
            let detLang = results.first?.language ?? "?"
            logger.notice("transcribe model=\(modelName, privacy: .public) audio=\(audioSec, privacy: .public)s wall=\(wallMs, privacy: .public)ms reqLang=\(reqLang, privacy: .public) detLang=\(detLang, privacy: .public)")

            let text = results.map(\.text).joined(separator: " ")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TranscribeError.transcriptionFailed(String(describing: error))
        }
    }
}
