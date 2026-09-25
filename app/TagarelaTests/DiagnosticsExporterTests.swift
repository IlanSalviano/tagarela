import XCTest
@testable import Tagarela

@MainActor
final class DiagnosticsExporterTests: XCTestCase {
    /// A exportação é o que o usuário manda quando a falha acontece — então
    /// precisa carregar o log, o retrato do estado, e **nada** de segredo.
    func test_exportWritesLogAndSnapshotWithoutSecrets() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
            .appendingPathComponent("diagexport-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let log = DiagnosticsLog(directory: tmp.appendingPathComponent("logs", isDirectory: true))
        log.append(level: "notice", category: "audio", message: "stop raw=48000 buffers=10")

        let health = PipelineHealth(launchedAt: Date(timeIntervalSince1970: 0),
                                    clock: { Date(timeIntervalSince1970: 3_600) })
        health.noteEmptyTranscription()

        let folder = try DiagnosticsExporter.export(
            .init(health: health, loadedModelName: "large-v3_turbo", modelDownloaded: true),
            log: log, destination: tmp, reveal: false)

        XCTAssertTrue(fm.fileExists(atPath: folder.appendingPathComponent("tagarela.log").path),
                      "log rotativo tem que ser copiado")
        let snapshot = try String(contentsOf: folder.appendingPathComponent("snapshot.txt"),
                                  encoding: .utf8)
        XCTAssertTrue(snapshot.contains("## saúde"))
        XCTAssertTrue(snapshot.contains("## permissões"))
        XCTAssertTrue(snapshot.contains("## event taps deste processo"))
        XCTAssertTrue(snapshot.contains("uptime do app: 1h 0m"), "veio:\n\(snapshot)")
        XCTAssertTrue(snapshot.contains("transcrições vazias: 1"))
        XCTAssertTrue(snapshot.contains("large-v3_turbo"))

        // Sem prefs a seção sai como indisponível — e em nenhum caso a
        // exportação lê o Keychain, onde mora a API key.
        XCTAssertFalse(snapshot.contains("sk-"))
        XCTAssertFalse(snapshot.lowercased().contains("apikey"))
    }
}
