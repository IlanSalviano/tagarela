import AVFoundation
import CoreAudio

private func fmt(_ value: Double, _ places: Int = 2) -> String {
    String(format: "%.\(places)f", value)
}

final class AudioCaptureLive: AudioCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var captureFormat: AVAudioFormat?
    /// Um array por canal — cada callback do tap concatena seus N samples
    /// no array do canal correspondente. Mantém a ordem temporal por canal.
    private var channelBuffers: [[Float]] = []
    private(set) var isRecording: Bool = false
    /// Quantos buffers o tap entregou nesta gravação, e desde quando ela corre.
    /// Servem ao diagnóstico: `raw=0` com `wall` longo é a assinatura de S1
    /// (auditoria §3.4), o candidato mais compatível com a queixa.
    private var buffersSeen: Int = 0
    private var startedAt: ContinuousClock.Instant?
    private let maxGainProvider: @Sendable () -> Float

    nonisolated(unsafe) private var levelContinuation: AsyncStream<Double>.Continuation?
    let levels: AsyncStream<Double>

    init(maxGainProvider: @escaping @Sendable () -> Float = { 20.0 }) {
        self.maxGainProvider = maxGainProvider
        var ref: AsyncStream<Double>.Continuation!
        self.levels = AsyncStream { c in ref = c }
        self.levelContinuation = ref
    }

    func start() throws {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        Diag.info(.audio, "start: mic auth=\(mic.rawValue)")
        if mic == .denied {
            throw AudioCaptureError.microphoneDenied
        }
        channelBuffers.removeAll()
        buffersSeen = 0
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        channelBuffers = Array(repeating: [], count: Int(inFormat.channelCount))
        if inFormat.sampleRate == 0 || inFormat.channelCount == 0 {
            Diag.error(.audio, "inputNode sem formato (sampleRate=\(inFormat.sampleRate) ch=\(inFormat.channelCount)) — provavelmente sem permissão de mic")
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
            Diag.error(.audio, "engine.start() falhou: \(String(describing: error))")
            throw AudioCaptureError.engineFailedToStart
        }
        isRecording = true
        startedAt = .now
        Diag.notice(.audio, "start in=\(Int(inFormat.sampleRate))Hz/\(inFormat.channelCount)ch device='\(Self.defaultInputDeviceName())'")
    }

    /// Nome do device de entrada default no CoreAudio. É diagnóstico: a auditoria
    /// viu a lista de devices de entrada mudar várias vezes por dia nesta máquina
    /// (iPhone via Continuity, C920 re-enumerada, DisplayLink), que é o gatilho
    /// plausível da hipótese H1 pro "parou de transcrever".
    private static func defaultInputDeviceName() -> String {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != AudioDeviceID(kAudioObjectUnknown) else { return "?" }

        var name = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil,
                                         &nameSize, &name) == noErr else {
            return "id=\(deviceID)"
        }
        return name as String
    }

    func stop() async throws -> AudioBuffer {
        guard isRecording else { throw AudioCaptureError.notRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        let now = ContinuousClock.now
        let wall: Double = startedAt.map { start in
            let d = start.duration(to: now)
            return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
        } ?? 0
        startedAt = nil
        let buffers = buffersSeen
        let perChannel = channelBuffers
        channelBuffers.removeAll()
        guard let inFormat = captureFormat else {
            Diag.error(.audio, "stop sem captureFormat (buffers=\(buffers) wall=\(fmt(wall))s)")
            return AudioBuffer(samples: [], sampleRate: 16_000)
        }
        let resampled = downmixAndResample(perChannel: perChannel, from: inFormat)
        let boosted = boostPeakNormalize(resampled)
        var rawPeak: Float = 0
        for s in resampled { let a = abs(s); if a > rawPeak { rawPeak = a } }
        var newPeak: Float = 0
        for s in boosted { let a = abs(s); if a > newPeak { newPeak = a } }
        let totalRaw = perChannel.reduce(0) { $0 + $1.count }
        Diag.notice(.audio, "stop raw=\(totalRaw) buffers=\(buffers) in=\(Int(inFormat.sampleRate))Hz/\(inFormat.channelCount)ch → 16k=\(resampled.count) peak \(fmt(Double(rawPeak), 3))→\(fmt(Double(newPeak), 3)) wall=\(fmt(wall))s")
        if totalRaw == 0 {
            Diag.error(.audio, "raw=0 — tap não entregou sample nenhum em \(fmt(wall))s (buffers=\(buffers) device='\(Self.defaultInputDeviceName())')")
        }
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
        // Limita gain ao cap do provider pra não amplificar ruído muito alto
        let cap = maxGainProvider()
        let gain = min(targetPeak / peak, cap)
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
        buffersSeen += 1

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
