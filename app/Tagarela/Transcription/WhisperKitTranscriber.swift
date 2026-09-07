import Foundation
import WhisperKit

/// Adaptador do WhisperKit (0.9+) pro protocolo Transcribing.
///
/// Carga do modelo: **prefere a pasta local**. `WhisperKit.download` chama
/// `HubApi.getFilenames`, que é um HTTP incondicional a `huggingface.co` mesmo
/// com o modelo já em disco — então um launch sem rede deixava o modelo sem
/// carregar e todo ditado virava "erro no pipeline" até relançar com internet
/// (auditoria §5.1). Num app local-first isso também era uma requisição de rede
/// a cada abertura.
final class WhisperKitTranscriber: Transcribing, @unchecked Sendable {
    typealias Downloader = @Sendable (String, @escaping (Double) -> Void) async throws -> URL

    private var pipe: WhisperKit?
    private var loadedFolder: URL?
    private(set) var loadedModelName: String?

    private let store: WhisperModelStore
    private let downloader: Downloader

    init(store: WhisperModelStore = WhisperModelStoreLive(),
         downloader: @escaping Downloader = { name, onProgress in
             try await WhisperKit.download(variant: name) { onProgress($0.fractionCompleted) }
         }) {
        self.store = store
        self.downloader = downloader
    }

    func loadModel(_ name: String,
                   onProgress: @escaping (Double) -> Void) async throws {
        do {
            let folder: URL
            if let local = store.modelFolderURL(for: name) {
                Diag.notice(.transcribe, "modelo '\(name)' já em disco — carregando sem rede")
                folder = local
                onProgress(1.0)
            } else {
                Diag.notice(.transcribe, "modelo '\(name)' ausente — baixando")
                folder = try await downloader(name, onProgress)
            }
            try await instantiate(folder: folder, name: name)
            Diag.notice(.transcribe, "loaded model=\(name)")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TranscribeError.modelDownloadFailed(String(describing: error))
        }
    }

    func unloadModel() {
        pipe = nil
        loadedFolder = nil
        loadedModelName = nil
        Diag.notice(.transcribe, "unloaded model")
    }

    func reload() async throws {
        guard let name = loadedModelName else { throw TranscribeError.modelNotLoaded }
        guard let folder = loadedFolder ?? store.modelFolderURL(for: name) else {
            throw TranscribeError.modelNotLoaded
        }
        Diag.error(.transcribe, "recarregando model=\(name) do disco")
        pipe = nil
        do {
            try await instantiate(folder: folder, name: name)
        } catch {
            Diag.error(.transcribe, "reload falhou: \(String(describing: error))")
            throw TranscribeError.modelDownloadFailed(String(describing: error))
        }
        Diag.notice(.transcribe, "reloaded model=\(name)")
    }

    private func instantiate(folder: URL, name: String) async throws {
        let config = WhisperKitConfig(
            modelFolder: folder.path,
            computeOptions: ModelComputeOptions(
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            ),
            prewarm: true,
            load: true
        )
        self.pipe = try await WhisperKit(config)
        self.loadedFolder = folder
        self.loadedModelName = name
    }

    func transcribe(buffer: AudioBuffer,
                    language: String?,
                    initialPrompt: String?) async throws -> TranscriptionOutcome {
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

            let text = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Métricas do último segmento: é onde um decoder degradado aparece
            // primeiro (noSpeechProb alto com pico de áudio bom).
            let segments = results.flatMap(\.segments)
            let last = segments.last
            let outcome = TranscriptionOutcome(
                text: text,
                detectedLanguage: results.first?.language,
                avgLogprob: last?.avgLogprob,
                compressionRatio: last?.compressionRatio,
                noSpeechProb: last?.noSpeechProb,
                wallMs: wallMs,
                segments: segments.count)

            let modelName = self.loadedModelName ?? "?"
            let audioSec = String(format: "%.1f", buffer.durationSeconds)
            let header = "model=\(modelName) audio=\(audioSec)s reqLang=\(language ?? "auto")"
            if text.isEmpty {
                Diag.error(.transcribe, "transcrição vazia — \(header) \(outcome.metricsLine)")
            } else {
                Diag.notice(.transcribe, "transcribe \(header) \(outcome.metricsLine)")
            }
            return outcome
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TranscribeError.transcriptionFailed(String(describing: error))
        }
    }
}
