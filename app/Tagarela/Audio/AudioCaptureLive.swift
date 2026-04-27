import AVFoundation
import OSLog

final class AudioCaptureLive: AudioCapturing, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Audio")
    private let engine = AVAudioEngine()
    private var captureFormat: AVAudioFormat?
    /// Um array por canal — cada callback do tap concatena seus N samples
    /// no array do canal correspondente. Mantém a ordem temporal por canal.
    private var channelBuffers: [[Float]] = []
    private(set) var isRecording: Bool = false

    nonisolated(unsafe) private var levelContinuation: AsyncStream<Double>.Continuation?
    let levels: AsyncStream<Double>

    init() {
        var ref: AsyncStream<Double>.Continuation!
        self.levels = AsyncStream { c in ref = c }
        self.levelContinuation = ref
    }

    func start() throws {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        FileHandle.standardError.write(Data("[audio] start: mic auth=\(mic.rawValue)\n".utf8))
        if mic == .denied {
            throw AudioCaptureError.microphoneDenied
        }
        channelBuffers.removeAll()
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        channelBuffers = Array(repeating: [], count: Int(inFormat.channelCount))
        FileHandle.standardError.write(Data("[audio] inFormat sampleRate=\(inFormat.sampleRate) channels=\(inFormat.channelCount)\n".utf8))
        if inFormat.sampleRate == 0 || inFormat.channelCount == 0 {
            FileHandle.standardError.write(Data("[audio] inputNode sem formato — provavelmente sem permissão de mic\n".utf8))
            throw AudioCaptureError.microphoneDenied
        }

        // Capturamos no formato nativo do device e convertemos no stop().
        // Evita problemas com AVAudioConverter de streaming que engasgam após
        // o primeiro buffer em alguns devices USB.
        self.captureFormat = inFormat
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buf, _ in
            guard let self else { return }
            self.append(buffer: buf)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            FileHandle.standardError.write(Data("[audio] engine.start() falhou: \(error)\n".utf8))
            throw AudioCaptureError.engineFailedToStart
        }
        isRecording = true
        FileHandle.standardError.write(Data("[audio] engine started successfully\n".utf8))
        logger.info("AudioCapture started")
    }

    func stop() async throws -> AudioBuffer {
        guard isRecording else { throw AudioCaptureError.notRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        let perChannel = channelBuffers
        channelBuffers.removeAll()
        guard let inFormat = captureFormat else {
            FileHandle.standardError.write(Data("[audio] stop sem captureFormat\n".utf8))
            return AudioBuffer(samples: [], sampleRate: 16_000)
        }
        let resampled = downmixAndResample(perChannel: perChannel, from: inFormat)
        let boosted = boostPeakNormalize(resampled)
        var rawPeak: Float = 0
        for s in resampled { let a = abs(s); if a > rawPeak { rawPeak = a } }
        var newPeak: Float = 0
        for s in boosted { let a = abs(s); if a > newPeak { newPeak = a } }
        let totalRaw = perChannel.reduce(0) { $0 + $1.count }
        FileHandle.standardError.write(Data("[audio] stop: raw=\(totalRaw) samples (\(inFormat.sampleRate)Hz, \(inFormat.channelCount)ch) → resampled=\(resampled.count) (16kHz mono) peak before=\(rawPeak) after=\(newPeak)\n".utf8))
        return AudioBuffer(samples: boosted, sampleRate: 16_000)
    }

    /// Boost peak-normalize: pegar peak e escalar pra targetPeak (com clipping suave).
    /// Compensa input gain baixo do device sem distorcer fala normal.
    private func boostPeakNormalize(_ samples: [Float], targetPeak: Float = 0.6) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var peak: Float = 0
        for s in samples {
            let a = abs(s)
            if a > peak { peak = a }
        }
        guard peak > 0.0001 else { return samples } // silêncio: não tenta boostar
        // Limita gain a 20x pra não amplificar ruído muito alto
        let gain = min(targetPeak / peak, 20)
        return samples.map { s in
            let g = s * gain
            return max(-1, min(1, g))
        }
    }

    /// Mixa múltiplos canais (mean) e resampla via interpolação linear pra 16kHz.
    /// Suficiente pra Whisper; alternativa séria seria AVAudioConverter offline.
    private func downmixAndResample(perChannel: [[Float]], from format: AVAudioFormat) -> [Float] {
        let channels = perChannel.count
        guard channels > 0 else { return [] }
        let samplesPerChannel = perChannel.map(\.count).min() ?? 0
        guard samplesPerChannel > 0 else { return [] }
        var mono = [Float](repeating: 0, count: samplesPerChannel)
        for c in 0..<channels {
            let buf = perChannel[c]
            for i in 0..<samplesPerChannel {
                mono[i] += buf[i]
            }
        }
        let inv = 1.0 / Float(channels)
        for i in 0..<mono.count { mono[i] *= inv }

        let inSR = format.sampleRate
        let outSR = 16_000.0
        if inSR == outSR { return mono }
        let ratio = inSR / outSR
        let outCount = Int(Double(samplesPerChannel) / ratio)
        var resampled = [Float](repeating: 0, count: outCount)
        for i in 0..<outCount {
            let srcF = Double(i) * ratio
            let srcI = Int(srcF)
            let frac = Float(srcF - Double(srcI))
            if srcI + 1 < samplesPerChannel {
                resampled[i] = mono[srcI] * (1 - frac) + mono[srcI + 1] * frac
            } else if srcI < samplesPerChannel {
                resampled[i] = mono[srcI]
            }
        }
        return resampled
    }

    /// Append raw samples no formato nativo do device. Cada canal acumula
    /// seus samples num array próprio, preservando ordem temporal —
    /// downmix + resample acontecem no stop().
    private func append(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        if channelBuffers.count < channels {
            channelBuffers.append(contentsOf:
                Array(repeating: [Float](), count: channels - channelBuffers.count))
        }
        for c in 0..<channels {
            let ptr = channelData[c]
            channelBuffers[c].append(contentsOf: UnsafeBufferPointer(start: ptr, count: n))
        }

        // Calcula nível (RMS) só do canal 0 (mais barato)
        let ptr0 = channelData[0]
        var sum: Float = 0
        for i in 0..<n { sum += ptr0[i] * ptr0[i] }
        let rms = sqrt(sum / Float(max(1, n)))
        let level = min(1.0, max(0.0, Double(rms) * 4))
        levelContinuation?.yield(level)
    }

    deinit { levelContinuation?.finish() }
}
