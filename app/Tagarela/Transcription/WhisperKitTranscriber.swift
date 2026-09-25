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

    /// Idioma principal do app ("foco em português com regionalização").
    static let primaryLanguage = "pt"

    /// "Automático", neste app, significa **português ou inglês** — o seletor
    /// só oferece os dois (ADR-0006). O Whisper escolhe entre ~99 idiomas, e
    /// português se confunde com espanhol, galego, italiano e francês. A regra:
    /// inglês se o Whisper disse inglês; português em qualquer outro caso.
    static func resolveAutoLanguage(_ detected: String) -> String {
        detected == "en" ? "en" : primaryLanguage
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

        // Modo Automático (language == nil): a detecção é feita **à parte**,
        // com o decoder limpo, e a transcrição roda com o idioma explícito.
        //
        // Não dá para deixar o WhisperKit detectar dentro do `transcribe`: no
        // 0.18.0 o `TranscribeTask` pré-preenche o KV cache com `<|en|>`
        // (`Constants.defaultLanguageCode`) **antes** de detectar, e a detecção
        // lê esse cache. A escolha sai corrompida — em campo, quatro ditados em
        // português viraram en, it, en, en (um de 32 s); no teste de
        // integração, 9,6 s de português virou `fr`. O `detectLangauge` público
        // monta o decoder do zero (`prepareDecoderInputs(withPrompt: [SOT])`),
        // então não herda o viés. Custa um encoder a mais; a transcrição em si
        // passa a seguir exatamente o caminho de idioma fixo, que é o que
        // funcionou por meses com `pt`.
        let effectiveLanguage: String
        var autoNote = ""
        if let language {
            effectiveLanguage = language
        } else {
            do {
                let detection = try await pipe.detectLangauge(audioArray: buffer.samples)
                effectiveLanguage = Self.resolveAutoLanguage(detection.language)
                autoNote = " auto=\(detection.language)→\(effectiveLanguage)"
            } catch {
                effectiveLanguage = Self.primaryLanguage
                autoNote = " auto=falhou→\(effectiveLanguage)"
                Diag.error(.transcribe, "detecção de idioma falhou: \(String(describing: error)) — usando \(effectiveLanguage)")
            }
        }

        let opts = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: effectiveLanguage,
            usePrefillPrompt: true,
            detectLanguage: false,
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
            let header = "model=\(modelName) audio=\(audioSec)s reqLang=\(language ?? "auto")\(autoNote)"
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
