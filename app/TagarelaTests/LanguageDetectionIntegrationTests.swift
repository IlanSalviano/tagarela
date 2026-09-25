import AVFoundation
import XCTest
@testable import Tagarela

/// Roda o modelo **real** sobre fala sintetizada. Só com `TAGARELA_INTEGRATION=1`
/// (carrega 3 GB de modelo e leva segundos):
///
///     TEST_RUNNER_TAGARELA_INTEGRATION=1 xcodebuild … test
///
/// Existe porque o bug que ele cobre só aparece com o WhisperKit de verdade:
/// em modo automático o `TranscribeTask` pré-preenche o KV cache do decoder com
/// `<|en|>` (`Constants.defaultLanguageCode`) **antes** de detectar o idioma, e
/// a detecção lê esse cache. Resultado de campo em 2026-09-24: quatro ditados em
/// português detectados como en, it, en e en — um deles com 32 segundos.
final class LanguageDetectionIntegrationTests: XCTestCase {

    private static let portugueseText =
        "Bom dia. Hoje eu vou ditar um texto em português para testar se o aplicativo "
        + "detecta o idioma corretamente, sem confundir com inglês ou italiano."

    func test_autoModeTranscribesPortugueseAsPortuguese_realModel() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TAGARELA_INTEGRATION"] == "1",
                          "roda só com TAGARELA_INTEGRATION=1 — carrega o modelo real")
        let store = WhisperModelStoreLive()
        try XCTSkipUnless(store.isDownloaded("large-v3_turbo"), "modelo large-v3_turbo não está em disco")

        let samples = try Self.synthesize(Self.portugueseText, voice: "Luciana")
        XCTAssertGreaterThan(samples.count, 16_000 * 5, "síntese curta demais: \(samples.count) samples")

        let transcriber = WhisperKitTranscriber()
        try await transcriber.loadModel("large-v3_turbo") { _ in }

        let outcome = try await transcriber.transcribe(
            buffer: AudioBuffer(samples: samples, sampleRate: 16_000),
            language: nil,               // modo Automático
            initialPrompt: nil)

        XCTAssertEqual(outcome.detectedLanguage, "pt",
                       "fala em português detectada como '\(outcome.detectedLanguage ?? "nil")'")
        XCTAssertTrue(outcome.text.lowercased().contains("português"),
                      "a saída deveria ser a transcrição em português, não uma tradução")
    }

    /// `say` gera float32 mono a 16 kHz direto, que é o formato do pipeline.
    static func synthesize(_ text: String, voice: String) throws -> [Float] {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tagarela-tts-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-v", voice, "--file-format=WAVE", "--data-format=LEF32@16000",
                         "-o", url.path, text]
        try say.run()
        say.waitUntilExit()

        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "tts", code: 1)
        }
        try file.read(into: buffer)
        guard let data = buffer.floatChannelData else { throw NSError(domain: "tts", code: 2) }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength)))
    }
}
