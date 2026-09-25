import XCTest
@testable import Tagarela

final class AudioMathTests: XCTestCase {

    // MARK: - downmix

    func test_downmixOfIdenticalChannelsPreservesSignal() {
        let channel: [Float] = [0.1, -0.2, 0.3, -0.4]
        let result = AudioMath.downmix(perChannel: [channel, channel])
        XCTAssertFalse(result.channelMismatch)
        for (got, want) in zip(result.samples, channel) {
            XCTAssertEqual(got, want, accuracy: 1e-6)
        }
    }

    /// O bug: o downmix usava o **menor** canal, então um canal vazio zerava a
    /// gravação inteira e ela virava "buffer curto" silencioso (S1).
    func test_emptyChannelDoesNotZeroTheResultAndFlagsMismatch() {
        let left: [Float] = [0.4, 0.4, 0.4, 0.4]
        let result = AudioMath.downmix(perChannel: [left, []])

        XCTAssertTrue(result.channelMismatch, "contagens diferentes têm que ser sinalizadas")
        XCTAssertEqual(result.samples.count, 4, "o resultado usa o maior canal, não o menor")
        XCTAssertEqual(AudioMath.peak(result.samples), 0.2, accuracy: 1e-6,
                       "sinal preservado (média com o canal mudo), não descartado")
    }

    func test_shorterChannelIsZeroFilled() {
        let result = AudioMath.downmix(perChannel: [[1.0, 1.0, 1.0], [1.0]])
        XCTAssertTrue(result.channelMismatch)
        XCTAssertEqual(result.samples.count, 3)
        XCTAssertEqual(result.samples[0], 1.0, accuracy: 1e-6)   // dois canais
        XCTAssertEqual(result.samples[2], 0.5, accuracy: 1e-6)   // só um canal
    }

    func test_downmixOfNothing() {
        XCTAssertEqual(AudioMath.downmix(perChannel: []).samples, [])
        XCTAssertEqual(AudioMath.downmix(perChannel: [[], []]).samples, [])
    }

    // MARK: - resample

    /// 48k → 16k de um seno de 440 Hz: a frequência tem que sobreviver.
    /// Conta cruzamentos por zero, que é proporcional à frequência.
    func test_resamplePreservesFrequency() {
        let inRate = 48_000.0, outRate = 16_000.0, hz = 440.0, seconds = 0.5
        let input = (0..<Int(inRate * seconds)).map {
            Float(sin(2 * Double.pi * hz * Double($0) / inRate))
        }
        let output = AudioMath.resampleLinear(input, from: inRate, to: outRate)

        XCTAssertEqual(output.count, Int(outRate * seconds), accuracy: 2)
        XCTAssertEqual(zeroCrossings(output), zeroCrossings(input), accuracy: 2,
                       "reamostragem não pode mudar a frequência do sinal")
    }

    func test_resampleIsIdentityAtSameRate() {
        let input: [Float] = [0.1, 0.2, 0.3]
        XCTAssertEqual(AudioMath.resampleLinear(input, from: 16_000, to: 16_000), input)
    }

    func test_resampleOfEmptyOrInvalid() {
        XCTAssertEqual(AudioMath.resampleLinear([], from: 48_000, to: 16_000), [])
        XCTAssertEqual(AudioMath.resampleLinear([0.5], from: 0, to: 16_000), [])
    }

    private func zeroCrossings(_ samples: [Float]) -> Int {
        var count = 0
        for index in 1..<max(1, samples.count) where samples[index - 1] < 0 && samples[index] >= 0 {
            count += 1
        }
        return count
    }

    // MARK: - normalização

    func test_peakNormalizeReachesTargetWhenGainAllows() {
        let out = AudioMath.peakNormalize([0.1, -0.05], targetPeak: 0.6, maxGain: 20)
        XCTAssertEqual(AudioMath.peak(out), 0.6, accuracy: 1e-5)
    }

    func test_peakNormalizeRespectsMaxGain() {
        // Precisaria de 60× pra chegar em 0.6; o teto é 4×.
        let out = AudioMath.peakNormalize([0.01], targetPeak: 0.6, maxGain: 4)
        XCTAssertEqual(AudioMath.peak(out), 0.04, accuracy: 1e-5)
    }

    func test_silenceIsNotBoosted() {
        let silence: [Float] = [0.00001, -0.00001, 0]
        let out = AudioMath.peakNormalize(silence, targetPeak: 0.6, maxGain: 20)
        XCTAssertEqual(out, silence, "silêncio amplificado 20× vira ruído — e alucinação no Whisper")
    }

    func test_peakNormalizeClipsToUnit() {
        let out = AudioMath.peakNormalize([0.5, -0.5], targetPeak: 5.0, maxGain: 20)
        XCTAssertLessThanOrEqual(AudioMath.peak(out), 1.0)
    }
}
