import XCTest
@testable import Tagarela

/// O log unificado desta máquina retém mensagens de apps de terceiros por ~1,5
/// dia e `.info` praticamente não persiste — foi por isso que a auditoria de
/// 2026-09-07 não conseguiu fechar a causa-raiz do "para de transcrever após
/// dias no ar". `DiagnosticsLog` é a metade durável do diagnóstico.
final class DiagnosticsLogTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diaglog-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
        try super.tearDownWithError()
    }

    private func lines(of name: String) throws -> [String] {
        let url = dir.appendingPathComponent(name)
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n").map(String.init)
    }

    // MARK: - formato da linha

    func test_append_writesISO8601TimestampLevelCategoryAndMessage() throws {
        let log = DiagnosticsLog(directory: dir)
        log.append(level: "notice", category: "audio", message: "stop raw=48000 buffers=10")

        let all = try lines(of: "tagarela.log")
        XCTAssertEqual(all.count, 1)
        let line = try XCTUnwrap(all.first)
        XCTAssertTrue(line.hasSuffix(" NOTICE [audio] stop raw=48000 buffers=10"),
                      "linha inesperada: \(line)")

        let stamp = String(line.prefix(while: { $0 != " " }))
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertNotNil(parser.date(from: stamp), "timestamp não é ISO-8601: \(stamp)")
    }

    func test_missingDirectoryIsCreated() throws {
        let nested = dir.appendingPathComponent("a/b/c", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: nested.path))

        let log = DiagnosticsLog(directory: nested)
        log.append(level: "error", category: "pipeline", message: "boom")

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: nested.appendingPathComponent("tagarela.log").path))
    }

    // MARK: - rotação

    func test_rotatesAtMaxBytesKeepingMaxFiles() throws {
        let log = DiagnosticsLog(directory: dir, maxBytes: 2_048, maxFiles: 3)
        // Cada linha tem ~90 bytes; 200 linhas passam de 2 KB várias vezes.
        for i in 0..<200 {
            log.append(level: "notice", category: "audio",
                       message: "linha \(i) com corpo suficiente pra encher o arquivo rápido")
        }

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("tagarela.log").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("tagarela.1.log").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("tagarela.2.log").path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("tagarela.3.log").path),
                       "não pode guardar mais que maxFiles arquivos")

        for name in ["tagarela.log", "tagarela.1.log", "tagarela.2.log"] {
            let size = try XCTUnwrap(
                fm.attributesOfItem(atPath: dir.appendingPathComponent(name).path)[.size] as? Int)
            XCTAssertLessThanOrEqual(size, 2_048 + 200, "\(name) passou do teto de rotação: \(size)")
        }

        // A linha mais recente tem que estar no arquivo corrente.
        let current = try lines(of: "tagarela.log")
        XCTAssertTrue(current.last?.contains("linha 199") == true,
                      "última linha deveria estar em tagarela.log, veio: \(current.last ?? "nil")")
    }

    // MARK: - concorrência

    func test_isSafeUnderConcurrentWriters() throws {
        let log = DiagnosticsLog(directory: dir)
        let total = 50
        DispatchQueue.concurrentPerform(iterations: total) { i in
            log.append(level: "notice", category: "audio", message: "thread-\(i)")
        }

        let all = try lines(of: "tagarela.log")
        XCTAssertEqual(all.count, total, "linhas perdidas ou duplicadas sob concorrência")

        // Nenhuma linha pode estar interleaved: toda linha casa o formato inteiro
        // e cada índice aparece exatamente uma vez.
        var seen = Set<Int>()
        for line in all {
            XCTAssertTrue(line.contains(" NOTICE [audio] thread-"), "linha corrompida: \(line)")
            let suffix = line.components(separatedBy: "thread-").last ?? ""
            let index = try XCTUnwrap(Int(suffix), "sufixo inesperado em: \(line)")
            XCTAssertTrue(seen.insert(index).inserted, "índice duplicado: \(index)")
        }
        XCTAssertEqual(seen.count, total)
    }

    // MARK: - leitura

    func test_contentsReturnsLastNLines() throws {
        let log = DiagnosticsLog(directory: dir)
        for i in 0..<20 { log.append(level: "notice", category: "app", message: "m\(i)") }

        let last5 = log.contents(limit: 5)
        XCTAssertEqual(last5.count, 5)
        XCTAssertTrue(last5.first?.hasSuffix("m15") == true, "veio: \(last5.first ?? "nil")")
        XCTAssertTrue(last5.last?.hasSuffix("m19") == true, "veio: \(last5.last ?? "nil")")
    }

    func test_contentsReadsAcrossRotatedFiles() throws {
        let log = DiagnosticsLog(directory: dir, maxBytes: 512, maxFiles: 3)
        for i in 0..<60 { log.append(level: "notice", category: "app", message: "m\(i)") }

        // Mais linhas do que cabem no arquivo corrente → tem que voltar pros rotacionados.
        let current = try lines(of: "tagarela.log")
        let wanted = current.count + 3
        let read = log.contents(limit: wanted)
        XCTAssertEqual(read.count, wanted, "contents deveria atravessar os arquivos rotacionados")
        XCTAssertTrue(read.last?.hasSuffix("m59") == true, "veio: \(read.last ?? "nil")")
    }
}

// MARK: - privacidade

extension DiagnosticsLogTests {
    /// Raiz dos fontes do app, derivada do `#filePath` deste arquivo de teste.
    private var sourcesRoot: URL? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TagarelaTests/
            .deletingLastPathComponent()   // app/
            .appendingPathComponent("Tagarela", isDirectory: true)
        return FileManager.default.fileExists(atPath: root.path) ? root : nil
    }

    /// Nenhuma chamada `Diag.*` pode interpolar o texto ditado, o conteúdo do
    /// clipboard ou a API key — só contagens, durações, formatos e métricas.
    ///
    /// Guarda concreta contra regressão: até a Fase 5 o `PipelineCoordinator`
    /// logava `transcribed: '\(raw)'`, ou seja, todo ditado do usuário ia parar
    /// no log. Agora que essas linhas também são gravadas em arquivo, o
    /// vazamento seria permanente.
    func test_noDictatedTextInSources() throws {
        guard let root = sourcesRoot else {
            throw XCTSkip("fontes do app indisponíveis a partir de #filePath")
        }
        let sensitive = ["raw", "refined", "text", "transcribed",
                         "clipboard", "apiKey", "prompt", "initialPrompt", "savedItems"]
        // Casa a interpolação da variável *inteira* — `\(raw)` e `\(raw, ...)`
        // são violação; `\(raw.count)` e `\(rawPeak)` não são.
        let pattern = "\\\\\\(\\s*(" + sensitive.joined(separator: "|") + ")\\s*[,)]"
        let regex = try NSRegularExpression(pattern: pattern)

        var offenders: [String] = []
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var scanned = 0
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scanned += 1
            for (offset, raw) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(raw)
                guard line.contains("Diag.notice(") || line.contains("Diag.error(")
                        || line.contains("Diag.info(") else { continue }
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    offenders.append("\(url.lastPathComponent):\(offset + 1): "
                                     + line.trimmingCharacters(in: .whitespaces))
                }
            }
        }

        XCTAssertGreaterThan(scanned, 50, "varredura não encontrou os fontes — teste seria vazio")
        XCTAssertTrue(offenders.isEmpty,
                      "Diag não pode logar conteúdo do usuário:\n" + offenders.joined(separator: "\n"))
    }
}
