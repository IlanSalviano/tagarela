import XCTest
@testable import Tagarela

@MainActor
final class PipelineHealthTests: XCTestCase {
    private let launch = Date(timeIntervalSince1970: 1_000_000)

    private func makeHealth(uptime: TimeInterval = 0) -> PipelineHealth {
        let launch = self.launch
        return PipelineHealth(launchedAt: launch, clock: { launch.addingTimeInterval(uptime) })
    }

    /// Uma gravação por *transição* para `.recording`. O estado é republicado
    /// 12–25×/s enquanto grava, então contar cada `.stateChanged` inflaria tudo.
    func test_recordingCountedOncePerRecordingDespiteRepeatedStates() {
        let h = makeHealth()
        h.noteState(.recording(elapsedSeconds: 0, audioLevel: 0))
        h.noteState(.recording(elapsedSeconds: 0.08, audioLevel: 0.3))
        h.noteState(.recording(elapsedSeconds: 0.16, audioLevel: 0.5))
        XCTAssertEqual(h.recordings, 1)

        h.noteState(.processing)
        h.noteState(.idle)
        h.noteState(.recording(elapsedSeconds: 0, audioLevel: 0))
        XCTAssertEqual(h.recordings, 2)
    }

    func test_countersIncrementIndependently() {
        let h = makeHealth()
        h.noteDiscardedShort()
        h.noteDiscardedShort()
        h.noteEmptyTranscription()
        h.noteInjectionFailure()
        h.noteRecovery()

        XCTAssertEqual(h.discardedShort, 2)
        XCTAssertEqual(h.emptyTranscriptions, 1)
        XCTAssertEqual(h.injectionFailures, 1)
        XCTAssertEqual(h.recoveries, 1)
        XCTAssertEqual(h.recordings, 0)
    }

    func test_consecutiveEmptyResetsOnSuccess() {
        let h = makeHealth()
        h.noteEmptyTranscription()
        h.noteEmptyTranscription()
        XCTAssertEqual(h.consecutiveEmpty, 2)
        XCTAssertEqual(h.emptyTranscriptions, 2)

        h.noteSuccess()
        XCTAssertEqual(h.consecutiveEmpty, 0, "sucesso zera a sequência")
        XCTAssertEqual(h.emptyTranscriptions, 2, "mas o total acumulado não regride")
    }

    /// Depois de recriar o transcriber a contagem recomeça — senão a próxima
    /// transcrição vazia dispararia recovery de novo na hora.
    func test_recoveryResetsConsecutiveEmpty() {
        let h = makeHealth()
        h.noteEmptyTranscription()
        h.noteEmptyTranscription()
        h.noteRecovery()
        XCTAssertEqual(h.consecutiveEmpty, 0)
    }

    func test_successStampsLastSuccessFromInjectedClock() {
        let h = makeHealth(uptime: 3_600)
        XCTAssertNil(h.lastSuccessAt)
        h.noteSuccess()
        XCTAssertEqual(h.lastSuccessAt, launch.addingTimeInterval(3_600))
    }

    func test_uptimeComesFromInjectedLaunchedAt() {
        XCTAssertEqual(makeHealth(uptime: 90).uptime, 90, accuracy: 0.001)
        XCTAssertEqual(makeHealth(uptime: 0).uptime, 0, accuracy: 0.001)
    }

    func test_uptimeLabelFormats() {
        XCTAssertEqual(makeHealth(uptime: 45).uptimeLabel, "45s")
        XCTAssertEqual(makeHealth(uptime: 12 * 60).uptimeLabel, "12m")
        XCTAssertEqual(makeHealth(uptime: 4 * 3_600 + 12 * 60).uptimeLabel, "4h 12m")
        XCTAssertEqual(makeHealth(uptime: 3 * 86_400 + 4 * 3_600).uptimeLabel, "3d 4h")
        // O caso que motivou a fase: quase 10 dias no ar.
        XCTAssertEqual(makeHealth(uptime: 9 * 86_400 + 13 * 3_600).uptimeLabel, "9d 13h")
    }

    func test_summaryLine() {
        let h = makeHealth(uptime: 3 * 86_400 + 4 * 3_600)
        for _ in 0..<12 {
            h.noteState(.recording(elapsedSeconds: 0, audioLevel: 0))
            h.noteState(.idle)
        }
        let line = h.summaryLine
        XCTAssertTrue(line.contains("12 ditados"), "veio: \(line)")
        XCTAssertTrue(line.contains("0 vazios"), "veio: \(line)")
        XCTAssertTrue(line.contains("0 curtos"), "veio: \(line)")
        XCTAssertTrue(line.contains("3d 4h"), "veio: \(line)")
    }

    func test_summaryLineReflectsDegradation() {
        let h = makeHealth(uptime: 60)
        h.noteState(.recording(elapsedSeconds: 0, audioLevel: 0))
        h.noteEmptyTranscription()
        h.noteDiscardedShort()
        let line = h.summaryLine
        XCTAssertTrue(line.contains("1 ditados"), "veio: \(line)")
        XCTAssertTrue(line.contains("1 vazios"), "veio: \(line)")
        XCTAssertTrue(line.contains("1 curtos"), "veio: \(line)")
    }
}
