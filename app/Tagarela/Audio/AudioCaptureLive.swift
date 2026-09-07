import AVFoundation
import CoreAudio
import os

private func fmt(_ value: Double, _ places: Int = 2) -> String {
    String(format: "%.\(places)f", value)
}

final class AudioCaptureLive: AudioCapturing, @unchecked Sendable {
    /// Estado escrito pela thread de render do tap e lido no `stop()`.
    /// Antes era acessado sem sincronização nenhuma.
    private struct TapState {
        var channelBuffers: [[Float]] = []
        var buffersSeen: Int = 0
    }
    private let tapState = OSAllocatedUnfairLock(uncheckedState: TapState())

    /// Engine **novo a cada gravação**. Custa milissegundos e elimina a classe
    /// inteira de falhas "o engine envelheceu ao longo de dias" — a hipótese H1
    /// da auditoria, que nenhuma inspeção conseguiu confirmar nem descartar.
    private var engine = AVAudioEngine()
    private var captureFormat: AVAudioFormat?
    private var configObserver: NSObjectProtocol?
    private var watchdog: Task<Void, Never>?
    private var startedAt: ContinuousClock.Instant?
    private var engineRecreated = false
    private var configurationChanged = false
    private var noAudioDelivered = false

    private(set) var isRecording = false
    private(set) var lastStats: CaptureStats?

    private let maxGainProvider: @Sendable () -> Float

    /// Um stream por gravação (ver contrato em `AudioCapturing.levels`).
    private(set) var levels = AsyncStream<Double> { $0.finish() }
    nonisolated(unsafe) private var levelContinuation: AsyncStream<Double>.Continuation?

    init(maxGainProvider: @escaping @Sendable () -> Float = { 20.0 }) {
        self.maxGainProvider = maxGainProvider
    }

    // MARK: - ciclo de vida

    func start() throws {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        Diag.info(.audio, "start: mic auth=\(mic.rawValue)")
        if mic == .denied { throw AudioCaptureError.microphoneDenied }

        engineRecreated = false
        configurationChanged = false
        noAudioDelivered = false
        tapState.withLock { $0 = TapState() }

        engine = AVAudioEngine()
        observeConfigurationChange()

        let (stream, continuation) = AsyncStream<Double>.makeStream()
        levels = stream
        levelContinuation = continuation

        do {
            try installTapAndStart()
        } catch {
            levelContinuation?.finish()
            levelContinuation = nil
            removeConfigurationObserver()
            throw error
        }

        isRecording = true
        startedAt = .now
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.watchdogFired()
        }
        Diag.notice(.audio, "start in=\(Int(captureFormat?.sampleRate ?? 0))Hz/"
                    + "\(captureFormat?.channelCount ?? 0)ch device='\(Self.defaultInputDeviceName())'")
    }

    func stop() async throws -> AudioBuffer {
        guard isRecording else { throw AudioCaptureError.notRecording }
        watchdog?.cancel()
        watchdog = nil

        let captured = teardownEngine()
        isRecording = false

        let wall: Double = startedAt.map { start in
            let elapsed = start.duration(to: .now)
            return Double(elapsed.components.seconds)
                 + Double(elapsed.components.attoseconds) / 1e18
        } ?? 0
        startedAt = nil

        // Finaliza o stream desta gravação: o consumidor termina sozinho.
        levelContinuation?.finish()
        levelContinuation = nil

        guard let inFormat = captureFormat else {
            Diag.error(.audio, "stop sem captureFormat (buffers=\(captured.buffersSeen) wall=\(fmt(wall))s)")
            throw AudioCaptureError.noAudioDelivered
        }

        let down = AudioMath.downmix(perChannel: captured.channelBuffers)
        let resampled = AudioMath.resampleLinear(down.samples, from: inFormat.sampleRate, to: 16_000)
        let peakBefore = AudioMath.peak(resampled)
        let boosted = AudioMath.peakNormalize(resampled, maxGain: maxGainProvider())
        let peakAfter = AudioMath.peak(boosted)
        let rawFrames = captured.channelBuffers.reduce(0) { $0 + $1.count }

        let stats = CaptureStats(
            rawFrames: rawFrames,
            buffers: captured.buffersSeen,
            inputSampleRate: inFormat.sampleRate,
            inputChannels: Int(inFormat.channelCount),
            resampledFrames: resampled.count,
            peakBefore: peakBefore,
            peakAfter: peakAfter,
            wallClockSeconds: wall,
            channelMismatch: down.channelMismatch,
            engineRecreated: engineRecreated,
            configurationChanged: configurationChanged)
        lastStats = stats

        Diag.notice(.audio, "stop raw=\(rawFrames) buffers=\(captured.buffersSeen) "
                    + "in=\(Int(inFormat.sampleRate))Hz/\(inFormat.channelCount)ch → 16k=\(resampled.count) "
                    + "peak \(fmt(Double(peakBefore), 3))→\(fmt(Double(peakAfter), 3)) wall=\(fmt(wall))s"
                    + (engineRecreated ? " [engine recriado]" : "")
                    + (configurationChanged ? " [config mudou]" : ""))

        if down.channelMismatch {
            Diag.error(.audio, "canais com contagens diferentes "
                       + "(\(captured.channelBuffers.map(\.count))) — completados com zero")
        }

        // A gravação correu tempo suficiente pra ter entregado áudio e não
        // entregou: é o S1 da auditoria §3.4, que até aqui era mudo.
        if noAudioDelivered || (resampled.isEmpty && wall >= 1.0) {
            Diag.error(.audio, "raw=0 — tap não entregou sample nenhum em \(fmt(wall))s "
                       + "(buffers=\(captured.buffersSeen) device='\(Self.defaultInputDeviceName())')")
            throw AudioCaptureError.noAudioDelivered
        }

        return AudioBuffer(samples: boosted, sampleRate: 16_000)
    }

    // MARK: - engine

    private func installTapAndStart() throws {
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        if inFormat.sampleRate == 0 || inFormat.channelCount == 0 {
            Diag.error(.audio, "inputNode sem formato (sampleRate=\(inFormat.sampleRate) "
                       + "ch=\(inFormat.channelCount)) — provavelmente sem permissão de mic")
            throw AudioCaptureError.microphoneDenied
        }
        captureFormat = inFormat
        tapState.withLock {
            $0.channelBuffers = Array(repeating: [], count: Int(inFormat.channelCount))
        }

        // Capturamos no formato nativo do device e convertemos no stop().
        // Evita o AVAudioConverter de streaming, que engasga após o primeiro
        // buffer em alguns devices USB.
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            // Sem isto o tap fica instalado e o próximo `start()` chama
            // `installTap` no mesmo bus → NSException (auditoria §5.1).
            input.removeTap(onBus: 0)
            Diag.error(.audio, "engine.start() falhou: \(String(describing: error))")
            throw AudioCaptureError.engineFailedToStart
        }
    }

    @discardableResult
    private func teardownEngine() -> TapState {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        removeConfigurationObserver()
        return tapState.withLock { state in
            let copy = state
            state = TapState()
            return copy
        }
    }

    /// Nenhum buffer em 1 s: derruba, recria e tenta uma vez. Se a segunda
    /// tentativa também não entregar nada, o `stop()` lança em vez de devolver
    /// silêncio — o caminho que hoje termina em "não fez nada, sem aviso".
    private func watchdogFired() {
        guard isRecording, tapState.withLock({ $0.buffersSeen }) == 0 else { return }
        Diag.error(.audio, "nenhum buffer após 1s; recriando o engine")
        engineRecreated = true

        teardownEngine()
        engine = AVAudioEngine()
        observeConfigurationChange()
        do {
            try installTapAndStart()
        } catch {
            noAudioDelivered = true
            Diag.error(.audio, "recriar o engine falhou: \(String(describing: error))")
            return
        }

        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.confirmRecreationWorked()
        }
    }

    private func confirmRecreationWorked() {
        guard isRecording, tapState.withLock({ $0.buffersSeen }) == 0 else { return }
        noAudioDelivered = true
        Diag.error(.audio, "ainda sem buffers depois de recriar o engine — "
                   + "a gravação vai falhar explicitamente")
    }

    private func observeConfigurationChange() {
        removeConfigurationObserver()
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil) { [weak self] _ in
                self?.configurationChanged = true
                Diag.error(.audio, "configuration change durante a gravação")
            }
    }

    private func removeConfigurationObserver() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
    }

    // MARK: - tap

    /// Roda na thread de render. Nada de I/O aqui — só acumular e medir.
    private func append(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)

        tapState.withLock { state in
            if state.channelBuffers.count < channels {
                state.channelBuffers.append(contentsOf:
                    Array(repeating: [Float](), count: channels - state.channelBuffers.count))
            }
            for channel in 0..<channels {
                state.channelBuffers[channel].append(
                    contentsOf: UnsafeBufferPointer(start: channelData[channel], count: frames))
            }
            state.buffersSeen += 1
        }

        // Nível (RMS) só do canal 0 — mais barato.
        var sum: Float = 0
        let first = channelData[0]
        for index in 0..<frames { sum += first[index] * first[index] }
        let rms = sqrt(sum / Float(max(1, frames)))
        levelContinuation?.yield(min(1.0, max(0.0, Double(rms) * 4)))
    }

    /// Nome do device de entrada default no CoreAudio. É diagnóstico: a auditoria
    /// viu a lista de devices mudar várias vezes por dia nesta máquina (iPhone
    /// via Continuity, C920 re-enumerada, DisplayLink).
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
                                         &nameSize, &name) == noErr else { return "id=\(deviceID)" }
        return name as String
    }

    deinit {
        watchdog?.cancel()
        removeConfigurationObserver()
        levelContinuation?.finish()
    }
}
