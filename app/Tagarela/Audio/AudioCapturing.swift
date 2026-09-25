import Foundation

protocol AudioCapturing: AnyObject, Sendable {
    /// Inicia captura. Erros: mic não autorizado, device indisponível.
    func start() throws

    /// Para captura, retorna o buffer PCM 16kHz mono Float32.
    /// Lança `.noAudioDelivered` quando o tap não entregou sample nenhum numa
    /// gravação que durou o suficiente para ter entregado.
    func stop() async throws -> AudioBuffer

    /// Stream do nível de áudio (RMS) entre 0...1, ~30 Hz, pra alimentar waveform.
    ///
    /// **Válido apenas para a gravação iniciada pelo último `start()`**: cada
    /// `start()` cria um stream novo e o `stop()` o finaliza. Obtenha-o
    /// **depois** de `start()`, e **não** cancele a Task que o consome —
    /// cancelar o consumidor termina o `AsyncStream`, que era exatamente o bug
    /// que deixava os indicadores em `audioLevel = 0` da segunda gravação em
    /// diante (auditoria §5.1).
    var levels: AsyncStream<Double> { get }

    var isRecording: Bool { get }

    /// Métricas da última gravação encerrada. Alimenta o log de diagnóstico e a
    /// decisão do pipeline entre "áudio ruim" e "captura falhou".
    var lastStats: CaptureStats? { get }
}

extension AudioCapturing {
    var lastStats: CaptureStats? { nil }
}

struct AudioBuffer: Equatable, Sendable {
    let samples: [Float]    // mono 16kHz
    let sampleRate: Double  // sempre 16000
    var durationSeconds: Double { Double(samples.count) / sampleRate }
}

/// Retrato do que a captura realmente viu. Existe porque a auditoria de
/// 2026-09-07 não conseguiu distinguir "o microfone não entregou nada" de
/// "o usuário falou baixo" — os dois davam no mesmo silêncio.
struct CaptureStats: Equatable, Sendable {
    var rawFrames: Int = 0
    var buffers: Int = 0
    var inputSampleRate: Double = 0
    var inputChannels: Int = 0
    var resampledFrames: Int = 0
    var peakBefore: Float = 0
    var peakAfter: Float = 0
    /// Duração real da gravação. Comparada com `resampledFrames`, denuncia a
    /// captura que "rodou" sem entregar áudio.
    var wallClockSeconds: Double = 0
    var channelMismatch: Bool = false
    var engineRecreated: Bool = false
    var configurationChanged: Bool = false
}

enum AudioCaptureError: Error, Equatable {
    case microphoneDenied
    case noInputDevice
    case engineFailedToStart
    case notRecording
    /// A gravação correu mas o tap não entregou sample nenhum.
    case noAudioDelivered
}
