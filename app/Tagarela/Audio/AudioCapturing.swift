import Foundation

protocol AudioCapturing: AnyObject, Sendable {
    /// Inicia captura. Erros: mic não autorizado, device indisponível.
    func start() throws

    /// Para captura, retorna o buffer PCM 16kHz mono Float32.
    func stop() async throws -> AudioBuffer

    /// Stream do nível de áudio (RMS) entre 0...1, ~30 Hz, pra alimentar waveform.
    var levels: AsyncStream<Double> { get }

    var isRecording: Bool { get }
}

struct AudioBuffer: Equatable, Sendable {
    let samples: [Float]    // mono 16kHz
    let sampleRate: Double  // sempre 16000
    var durationSeconds: Double { Double(samples.count) / sampleRate }
}

enum AudioCaptureError: Error, Equatable {
    case microphoneDenied
    case noInputDevice
    case engineFailedToStart
    case notRecording
}
