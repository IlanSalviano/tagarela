import AVFoundation
import OSLog

final class AudioCaptureLive: AudioCapturing, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Audio")
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
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
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: 16_000,
                                             channels: 1,
                                             interleaved: false) else {
            FileHandle.standardError.write(Data("[audio] outFormat creation failed\n".utf8))
            throw AudioCaptureError.engineFailedToStart
        }
        guard let conv = AVAudioConverter(from: inFormat, to: outFormat) else {
            FileHandle.standardError.write(Data("[audio] converter creation failed\n".utf8))
            throw AudioCaptureError.engineFailedToStart
        }
        self.converter = conv

        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buf, _ in
            guard let self else { return }
            self.process(buffer: buf, converter: conv, outFormat: outFormat)
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
        let samples = collected
        collected.removeAll()
        return AudioBuffer(samples: samples, sampleRate: 16_000)
    }

    private func process(buffer: AVAudioPCMBuffer,
                         converter: AVAudioConverter,
                         outFormat: AVAudioFormat) {
        let outFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000.0 / buffer.format.sampleRate) + 256
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outFrameCapacity) else { return }
        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outBuf, error: &error) { _, statusPtr in
            if consumed { statusPtr.pointee = .endOfStream; return nil }
            consumed = true
            statusPtr.pointee = .haveData
            return buffer
        }
        if status == .error || error != nil {
            logger.error("converter failed: \(String(describing: error))")
            return
        }
        guard let ch = outBuf.floatChannelData?[0] else { return }
        let n = Int(outBuf.frameLength)
        let arr = Array(UnsafeBufferPointer(start: ch, count: n))
        collected.append(contentsOf: arr)

        let rms = sqrt(arr.reduce(0) { $0 + $1 * $1 } / Float(max(1, n)))
        let level = min(1.0, max(0.0, Double(rms) * 4)) // gain visual
        levelContinuation?.yield(level)
    }

    deinit { levelContinuation?.finish() }
}
