import XCTest
@testable import Tagarela

final class PipelineCoordinatorTests: XCTestCase {
    func test_toggleFromIdle_movesToRecording() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        let s = await p.state
        if case .recording = s {} else { XCTFail("expected recording, got \(s)") }
    }

    func test_toggleFromRecording_runsPipelineAndReturnsToIdle() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        await p.handle(.toggle)
        // dar tempo da pipeline rodar (fakes são síncronos suficientes)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    func test_cancelDuringRecording_returnsToIdle() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        await p.handle(.cancel)
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    func test_refinerFails_fallsBackToIdentity() async {
        let p = makeCoordinator(refiner: FakeRefiner(kind: .openai, result: .failure(RefinerError.networkOffline)))
        let received = collectFinished(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let r = await received.value
        XCTAssertEqual(r?.refinedText, "olá mundo", "fallback Identity should pass through raw text")
    }

    func test_cancelledError_abortsWithoutFallback() async {
        let p = makeCoordinator(refiner: FakeRefiner(kind: .openai, result: .failure(RefinerError.cancelled)))
        let received = collectFinished(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let r = await received.value
        XCTAssertNil(r, "cancelled error should NOT yield finished event")
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    func test_identityRefiner_skipsRefiningState() async {
        let p = makeCoordinator(refiner: IdentityRefiner())
        let states = collectStates(from: p)
        await p.handle(.toggle)
        await p.handle(.toggle)
        try? await Task.sleep(nanoseconds: 200_000_000)
        let collected = await states.value
        // Esperado: idle, recording, processing, idle (sem .refining)
        XCTAssertFalse(collected.contains { if case .refining = $0 { return true } else { return false } },
                       "Identity should skip .refining; collected: \(collected)")
    }

    // Helpers ----------------------------------------------------

    private func makeCoordinator(refiner: TextRefiner = IdentityRefiner(),
                                 style: Style = BuiltInStyles.conversaInformal) -> PipelineCoordinator {
        PipelineCoordinator(
            audio: FakeAudio(),
            transcriber: FakeTranscriber(),
            refinerProvider: { @MainActor in (refiner, style) },
            injector: FakeInjector()
        )
    }

    private func collectFinished(from p: PipelineCoordinator) -> Task<(rawText: String, refinedText: String, frontmostApp: String?)?, Never> {
        Task {
            for await ev in p.events {
                if case let .finished(raw, refined, app) = ev {
                    return (raw, refined, app)
                }
                if case .stateChanged(.idle) = ev {
                    // .idle reached without .finished — provavelmente cancel/error
                    return nil
                }
            }
            return nil
        }
    }

    private func collectStates(from p: PipelineCoordinator) -> Task<[PipelineState], Never> {
        Task {
            var collected: [PipelineState] = []
            for await ev in p.events {
                if case .stateChanged(let s) = ev {
                    collected.append(s)
                    if case .idle = s, collected.count > 1 { break }
                }
            }
            return collected
        }
    }
}

actor ActorBool {
    private var v: Bool = false
    func set(_ b: Bool) { v = b }
    func get() -> Bool { v }
}

private final class FakeRefiner: TextRefiner, @unchecked Sendable {
    let kind: RefinerKind
    let result: Result<String, Error>
    let onCalled: (@Sendable () async -> Void)?

    init(kind: RefinerKind, result: Result<String, Error>, onCalled: (@Sendable () async -> Void)? = nil) {
        self.kind = kind
        self.result = result
        self.onCalled = onCalled
    }

    func refine(_ raw: String, style: Style) async throws -> String {
        await onCalled?()
        switch result {
        case .success(let s): return s
        case .failure(let e): throw e
        }
    }
}

private final class FakeAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    let levels = AsyncStream<Double> { _ in }
    func start() throws { isRecording = true }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000), sampleRate: 16_000)
    }
}

private final class FakeTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        "olá mundo"
    }
}

private final class FakeInjector: Injecting, @unchecked Sendable {
    var injected: String?
    func inject(text: String) async throws -> String? {
        injected = text
        return "com.example.app"
    }
}
