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
        let coord = makeCoord(initialActive: "large-v3-turbo", stagingBehavior: .immediateSuccess)
        coord.requestSwap(target: "large-v3-turbo")
        XCTAssertEqual(coord.state, .idle(active: "large-v3-turbo"))
    }

    func test_requestSwap_happyPath_endsInIdleAtTarget() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        var swappedFrom: String?
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in
                swappedFrom = oldT.loadedModelName
                return oldT
            }
        )
        coord.requestSwap(target: "large-v3-turbo")
        await Task.yield()
        await waitFor { coord.state == .idle(active: "large-v3-turbo") }
        XCTAssertEqual(swappedFrom, "large-v3")
        XCTAssertNil(oldT.loadedModelName)  // unloadModel foi chamado
    }

    func test_requestSwap_downloadFails_endsInFailedDownloadFailed() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("network err")
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3-turbo")
        await waitFor {
            if case .failed(_, _, let err) = coord.state {
                return err == .downloadFailed("network err")
            }
            return false
        }
    }

    func test_retry_afterFailure_reentersDownloading() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("network")
        var produced = 0
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { produced += 1; return newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3-turbo")
        await waitFor {
            if case .failed = coord.state { return true }
            return false
        }
        // Limpar erro pra retry passar
        newT.loadError = nil
        coord.retry()
        await waitFor { coord.state == .idle(active: "large-v3-turbo") }
        XCTAssertEqual(produced, 2, "stagingFactory é invocada por tentativa (uma no requestSwap inicial + uma no retry); se mudar pra reusar, ajustar este teste")
    }

    func test_cancel_duringDownload_returnsToIdleWithOldActive() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        newT.loadDelayNs = 500_000_000  // 0.5s — tempo pra cancelar antes
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3-turbo")
        try? await Task.sleep(nanoseconds: 50_000_000)
        coord.cancel()
        await waitFor { coord.state == .idle(active: "large-v3") }
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

    init(name: String) { self.loadedModelName = name }

    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {
        if loadDelayNs > 0 {
            try await Task.sleep(nanoseconds: loadDelayNs)
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
