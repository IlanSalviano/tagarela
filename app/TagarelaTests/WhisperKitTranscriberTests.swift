import XCTest
@testable import Tagarela

/// Cobre só a lógica de escolha entre disco e download — o WhisperKit real não
/// entra aqui. O que importa é a decisão, porque era ela que quebrava o app num
/// launch sem rede.
final class WhisperKitTranscriberTests: XCTestCase {

    /// `WhisperKit.download` chama `HubApi.getFilenames`, um HTTP incondicional
    /// a huggingface.co, **antes** do snapshot — mesmo com o modelo já em disco.
    /// Launch sem internet deixava o modelo sem carregar e todo ditado virava
    /// "erro no pipeline" até relançar com rede (auditoria §5.1).
    func test_modelPresentOnDisk_doesNotHitTheDownloader() async {
        let store = FakeModelStore(present: ["large-v3_turbo": URL(fileURLWithPath: "/tmp/whisper-fake")])
        let downloader = DownloadSpy()
        let transcriber = WhisperKitTranscriber(store: store, downloader: downloader.download)

        // O WhisperKit real vai falhar ao instanciar sobre uma pasta falsa; o que
        // este teste afirma é que o downloader não foi chamado antes disso.
        _ = try? await transcriber.loadModel("large-v3_turbo") { _ in }

        XCTAssertEqual(downloader.calls, 0, "modelo em disco não pode disparar rede")
        XCTAssertEqual(store.askedFor, ["large-v3_turbo"])
    }

    func test_modelAbsent_callsTheDownloader() async {
        let store = FakeModelStore(present: [:])
        let downloader = DownloadSpy()
        let transcriber = WhisperKitTranscriber(store: store, downloader: downloader.download)

        _ = try? await transcriber.loadModel("medium") { _ in }

        XCTAssertEqual(downloader.calls, 1, "modelo ausente tem que baixar")
        XCTAssertEqual(downloader.lastName, "medium")
    }

    func test_reloadWithoutLoadedModelThrows() async {
        let transcriber = WhisperKitTranscriber(store: FakeModelStore(present: [:]),
                                                downloader: DownloadSpy().download)
        do {
            try await transcriber.reload()
            XCTFail("reload sem modelo carregado deveria lançar")
        } catch {
            XCTAssertEqual(error as? TranscribeError, .modelNotLoaded)
        }
    }

    func test_outcomeMetricsLineHasNoText() {
        let outcome = TranscriptionOutcome(text: "conteúdo secreto do usuário",
                                           detectedLanguage: "pt",
                                           avgLogprob: -0.25,
                                           compressionRatio: 1.8,
                                           noSpeechProb: 0.02,
                                           wallMs: 900,
                                           segments: 3)
        let line = outcome.metricsLine
        XCTAssertFalse(line.contains("conteúdo"), "métricas não podem carregar o ditado")
        XCTAssertTrue(line.contains("chars=27"))
        XCTAssertTrue(line.contains("lang=pt"))
        XCTAssertTrue(line.contains("nsp=0.020"))
    }
}

private final class FakeModelStore: WhisperModelStore, @unchecked Sendable {
    private let present: [String: URL]
    private let lock = NSLock()
    private var asked: [String] = []
    var askedFor: [String] { lock.lock(); defer { lock.unlock() }; return asked }

    init(present: [String: URL]) { self.present = present }

    func isDownloaded(_ name: String) -> Bool { present[name] != nil }
    func modelFolderURL(for name: String) -> URL? {
        lock.lock(); asked.append(name); lock.unlock()
        return present[name]
    }
    func sizeOnDisk(_ name: String) -> Int64? { nil }
    func delete(_ name: String) async throws {}
}

private final class DownloadSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var name: String?
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    var lastName: String? { lock.lock(); defer { lock.unlock() }; return name }

    var download: WhisperKitTranscriber.Downloader {
        { [self] variant, _ in
            lock.lock(); count += 1; name = variant; lock.unlock()
            return URL(fileURLWithPath: "/tmp/whisper-downloaded")
        }
    }
}
