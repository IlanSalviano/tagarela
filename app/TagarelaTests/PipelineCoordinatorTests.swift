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

    private func makeCoordinator() -> PipelineCoordinator {
        PipelineCoordinator(
            audio: FakeAudio(),
            transcriber: FakeTranscriber(),
            refiner: IdentityRefiner(),
            injector: FakeInjector()
        )
    }
}

private final class FakeAudio: AudioCapturing, @unchecked Sendable {
    var isRecording = false
    let levels = AsyncStream<Double> { _ in }
    func start() throws { isRecording = true }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000),
                           sampleRate: 16_000) // 1s
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
