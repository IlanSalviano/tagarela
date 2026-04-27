import AVFoundation
import OSLog

final class AudioCaptureLive: AudioCapturing, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Audio")
    private let engine = AVAudioEngine()
    private var captureFormat: AVAudioFormat?
    private var collected: [Float] = []
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
        collected.removeAll()
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
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
        let raw = collected
        collected.removeAll()
        guard let inFormat = captureFormat else {
            FileHandle.standardError.write(Data("[audio] stop sem captureFormat\n".utf8))
            return AudioBuffer(samples: [], sampleRate: 16_000)
        }
        let resampled = downmixAndResample(raw, from: inFormat)
        FileHandle.standardError.write(Data("[audio] stop: raw=\(raw.count) samples (\(inFormat.sampleRate)Hz, \(inFormat.channelCount)ch) → resampled=\(resampled.count) (16kHz mono)\n".utf8))
        return AudioBuffer(samples: resampled, sampleRate: 16_000)
    }

    /// Mixa múltiplos canais (mean) e resampla via interpolação linear pra 16kHz.
    /// Suficiente pra Whisper; alternativa séria seria AVAudioConverter offline.
    private func downmixAndResample(_ raw: [Float], from format: AVAudioFormat) -> [Float] {
        let channels = Int(format.channelCount)
        guard channels > 0, !raw.isEmpty else { return [] }
        // raw está em ordem deinterleaved (canal 0 todo, depois canal 1, etc) por causa
        // do append(buffer:) que copia floatChannelData[i]. Vide append().
        let samplesPerChannel = raw.count / channels
        var mono = [Float](repeating: 0, count: samplesPerChannel)
        for c in 0..<channels {
            let base = c * samplesPerChannel
            for i in 0..<samplesPerChannel {
                mono[i] += raw[base + i]
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

    /// Append raw samples no formato nativo do device. Stereo deinterleaved,
    /// downmix + resample acontecem no stop().
    private func append(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        // Coletamos por canal: bloco de canal 0, depois canal 1, etc.
        // (Não interleavar — assim o downmix no stop() é simples.)
        for c in 0..<channels {
            let ptr = channelData[c]
            collected.append(contentsOf: UnsafeBufferPointer(start: ptr, count: n))
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
