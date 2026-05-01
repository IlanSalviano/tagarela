import XCTest
import Combine
@testable import Tagarela

@MainActor
final class WhisperModelSwapCoordinatorTests: XCTestCase {

    func test_initialState_isIdleWithGivenActive() {
        let coord = makeCoord(initialActive: "large-v3", stagingBehavior: .immediateSuccess)
        XCTAssertEqual(coord.state, .idle(active: "large-v3"))
    }

    func test_requestSwap_sameModel_noop() {
        let coord = makeCoord(initialActive: "large-v3_turbo", stagingBehavior: .immediateSuccess)
        coord.requestSwap(target: "large-v3_turbo")
        XCTAssertEqual(coord.state, .idle(active: "large-v3_turbo"))
    }

    func test_requestSwap_happyPath_endsInIdleAtTarget() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3_turbo")
        var swappedFrom: String?
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in
                swappedFrom = oldT.loadedModelName
                return oldT
            }
        )
        coord.requestSwap(target: "large-v3_turbo")
        await Task.yield()
        await waitFor { coord.state == .idle(active: "large-v3_turbo") }
        XCTAssertEqual(swappedFrom, "large-v3")
        XCTAssertNil(oldT.loadedModelName)  // unloadModel foi chamado
    }

    func test_requestSwap_downloadFails_endsInFailedDownloadFailed() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3_turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("network err")
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3_turbo")
        await waitFor {
            if case .failed(_, _, let err) = coord.state {
                return err == .downloadFailed("network err")
            }
            return false
        }
    }

    func test_retry_afterFailure_reentersDownloading() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3_turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("network")
        var produced = 0
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { produced += 1; return newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3_turbo")
        await waitFor {
            if case .failed = coord.state { return true }
            return false
        }
        // Limpar erro pra retry passar
        newT.loadError = nil
        coord.retry()
        await waitFor { coord.state == .idle(active: "large-v3_turbo") }
        XCTAssertEqual(produced, 2, "stagingFactory é invocada por tentativa (uma no requestSwap inicial + uma no retry); se mudar pra reusar, ajustar este teste")
    }

    func test_cancel_duringDownload_returnsToIdleWithOldActive() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3_turbo")
        newT.loadDelayNs = 500_000_000  // 0.5s — tempo pra cancelar antes
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3_turbo")
        try? await Task.sleep(nanoseconds: 50_000_000)
        coord.cancel()
        await waitFor { coord.state == .idle(active: "large-v3") }
    }

    func test_cancel_duringDownload_evenWhenLoadModelRewrapsCancellation() async {
        // Produção: WhisperKitTranscriber.loadModel pode rewrap CancellationError
        // como TranscribeError.modelDownloadFailed (regressão potencial). Mesmo
        // assim, cancel durante download deve voltar pra idle, não pra failed.
        // Hoje WhisperKitTranscriber NÃO faz esse rewrap (T5 review C1 fix), mas
        // este teste documenta o contrato pra evitar regressão silenciosa.
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3_turbo")
        newT.loadDelayNs = 500_000_000
        newT.loadErrorIfTaskCancelled = TranscribeError.modelDownloadFailed("cancelled")
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3_turbo")
        try? await Task.sleep(nanoseconds: 50_000_000)
        coord.cancel()
        // Allow time for state to settle
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Either .idle (preferred) or .failed (acceptable degradation): the key
        // assertion is that we did NOT lose the .idle path. With the C1 fix,
        // CancellationError propagates and we land in .idle.
        if case .idle(let active) = coord.state {
            XCTAssertEqual(active, "large-v3")
        } else if case .failed(let active, _, .downloadFailed) = coord.state {
            XCTFail("regression: CancellationError was rewrapped — coordinator landed in .failed instead of .idle. active=\(active)")
        } else {
            XCTFail("unexpected state \(coord.state)")
        }
    }

    func test_dismissError_fromFailed_returnsToIdle() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3_turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("err")
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3_turbo")
        await waitFor {
            if case .failed = coord.state { return true }
            return false
        }
        coord.dismissError()
        XCTAssertEqual(coord.state, .idle(active: "large-v3"))
    }

    func test_requestSwap_fromFailed_switchesTarget() async {
        let oldT = FakeT(name: "large-v3")
        let newTurbo = FakeT(name: "large-v3_turbo")
        let newMedium = FakeT(name: "medium")
        newTurbo.loadError = TranscribeError.modelDownloadFailed("err")
        var pickedFactory = 0
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: {
                pickedFactory += 1
                return pickedFactory == 1 ? newTurbo : newMedium
            },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3_turbo")
        await waitFor {
            if case .failed = coord.state { return true }
            return false
        }
        // From .failed, user picks a different target — should pivot.
        coord.requestSwap(target: "medium")
        await waitFor { coord.state == .idle(active: "medium") }
    }

    func test_dismissError_whenNotFailed_isNoop() {
        let coord = makeCoord(initialActive: "large-v3", stagingBehavior: .immediateSuccess)
        coord.dismissError()
        XCTAssertEqual(coord.state, .idle(active: "large-v3"))
    }

    // MARK: - Helpers

    private func makeCoord(initialActive: String,
                           stagingBehavior: StagingBehavior) -> WhisperModelSwapCoordinator {
        let staging = FakeT(name: "target")
        switch stagingBehavior {
        case .immediateSuccess: break
        case .immediateFailure(let err): staging.loadError = err
        }
        return WhisperModelSwapCoordinator(
            initialActive: initialActive,
            stagingFactory: { staging },
            swapActive: { _ in FakeT(name: initialActive) }
        )
    }

    private enum StagingBehavior {
        case immediateSuccess
        case immediateFailure(Error)
    }

    private func waitFor(_ predicate: @escaping () -> Bool,
                         timeoutSec: Double = 2.0) async {
        let deadline = Date().addingTimeInterval(timeoutSec)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("waitFor timeout")
    }
}

private final class FakeT: Transcribing, @unchecked Sendable {
    var loadedModelName: String?
    var loadError: Error?
    var loadDelayNs: UInt64 = 0
    /// Se setado, transforma CancellationError em outro erro (emula
    /// WhisperKitTranscriber rewrap pre-C1-fix).
    var loadErrorIfTaskCancelled: Error?

    init(name: String) { self.loadedModelName = name }

    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {
        do {
            if loadDelayNs > 0 {
                try await Task.sleep(nanoseconds: loadDelayNs)
            }
        } catch is CancellationError {
            if let rewrap = loadErrorIfTaskCancelled {
                throw rewrap
            }
            throw CancellationError()
        }
        if let err = loadError { throw err }
        onProgress(1.0)
        loadedModelName = name
    }

    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        ""
    }

    func unloadModel() {
        loadedModelName = nil
    }
}
