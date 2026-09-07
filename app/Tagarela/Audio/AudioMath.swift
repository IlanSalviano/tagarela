import Foundation

/// Matemática de áudio da captura, extraída do `AudioCaptureLive` para poder
/// ser testada sem microfone. A qualidade do ASR depende inteiramente destas
/// três operações e nenhuma tinha teste antes da Fase 5.
enum AudioMath {
    struct DownmixResult: Equatable {
        let samples: [Float]
        /// Canais chegaram com contagens diferentes. Antes isso zerava a
        /// gravação inteira (o downmix usava o **menor** canal); agora é só um
        /// sinal — mas um sinal que merece `.error` no log, porque é uma das
        /// formas de produzir o S1 silencioso da auditoria §3.4.
        let channelMismatch: Bool
    }

    /// Mixa os canais pela média. Usa o **maior** canal e completa os menores
    /// com zero: um canal vazio não pode mais descartar a gravação toda.
    static func downmix(perChannel: [[Float]]) -> DownmixResult {
        let channels = perChannel.count
        guard channels > 0 else { return DownmixResult(samples: [], channelMismatch: false) }
        let counts = perChannel.map(\.count)
        guard let longest = counts.max(), longest > 0 else {
            return DownmixResult(samples: [], channelMismatch: false)
        }
        let mismatch = (counts.min() ?? 0) != longest

        var mono = [Float](repeating: 0, count: longest)
        for channel in perChannel {
            for index in 0..<channel.count { mono[index] += channel[index] }
        }
        let inverse = 1.0 / Float(channels)
        for index in 0..<longest { mono[index] *= inverse }
        return DownmixResult(samples: mono, channelMismatch: mismatch)
    }

    /// Reamostragem por interpolação linear. Sem filtro anti-aliasing — o
    /// upgrade para `AVAudioConverter` offline está no backlog P2 da auditoria.
    static func resampleLinear(_ samples: [Float], from inRate: Double, to outRate: Double) -> [Float] {
        guard !samples.isEmpty, inRate > 0, outRate > 0 else { return [] }
        if inRate == outRate { return samples }
        let ratio = inRate / outRate
        let outCount = Int(Double(samples.count) / ratio)
        guard outCount > 0 else { return [] }
        var out = [Float](repeating: 0, count: outCount)
        for index in 0..<outCount {
            let source = Double(index) * ratio
            let whole = Int(source)
            let fraction = Float(source - Double(whole))
            if whole + 1 < samples.count {
                out[index] = samples[whole] * (1 - fraction) + samples[whole + 1] * fraction
            } else if whole < samples.count {
                out[index] = samples[whole]
            }
        }
        return out
    }

    static func peak(_ samples: [Float]) -> Float {
        var peak: Float = 0
        for sample in samples {
            let magnitude = abs(sample)
            if magnitude > peak { peak = magnitude }
        }
        return peak
    }

    /// Escala o pico para `targetPeak`, limitado por `maxGain`, com clipping
    /// suave. Compensa input gain baixo do device sem distorcer fala normal.
    static func peakNormalize(_ samples: [Float],
                              targetPeak: Float = 0.6,
                              maxGain: Float) -> [Float] {
        guard !samples.isEmpty else { return samples }
        let current = peak(samples)
        guard current > 0.0001 else { return samples } // silêncio: não boosta
        let gain = min(targetPeak / current, maxGain)
        return samples.map { max(-1, min(1, $0 * gain)) }
    }
}
