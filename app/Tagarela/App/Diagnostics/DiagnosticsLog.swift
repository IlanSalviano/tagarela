import Foundation
import os

/// Log em arquivo texto, rotativo, escrito de qualquer thread.
///
/// Existe porque o log unificado não serve para a falha que esta fase persegue:
/// nesta máquina a retenção efetiva para o processo do app é de ~1,5 dia e o
/// nível `.info` praticamente não chega ao disco, então um "parou de transcrever"
/// de dias atrás não deixa rastro recuperável (auditoria 2026-09-07, §3.2).
///
/// Toda mutação é serializada por um lock: `append` é chamado do run loop, de
/// Tasks e do caminho de controle do áudio. O caminho de render (o bloco do tap)
/// **não** loga — file I/O não tem lugar numa thread de áudio.
final class DiagnosticsLog: @unchecked Sendable {
    static let shared = DiagnosticsLog(directory: DiagnosticsLog.defaultDirectory)

    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Tagarela", isDirectory: true)
    }

    let directory: URL
    private let baseName: String
    private let ext: String
    private let maxBytes: Int
    private let maxFiles: Int
    private let state: OSAllocatedUnfairLock<State>

    private struct State {
        var handle: FileHandle?
        var size: Int = 0
        /// Mora no estado protegido de propósito: formatar dentro do lock evita
        /// compartilhar o formatter entre instâncias e garante que a ordem dos
        /// timestamps é a mesma ordem das linhas no arquivo.
        let stamper: ISO8601DateFormatter
    }

    init(directory: URL,
         fileName: String = "tagarela.log",
         maxBytes: Int = 5_000_000,
         maxFiles: Int = 3) {
        self.directory = directory
        let parsed = URL(fileURLWithPath: fileName)
        self.baseName = parsed.deletingPathExtension().lastPathComponent
        self.ext = parsed.pathExtension.isEmpty ? "log" : parsed.pathExtension
        self.maxBytes = max(1_024, maxBytes)
        self.maxFiles = max(1, maxFiles)

        let stamper = ISO8601DateFormatter()
        stamper.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.state = OSAllocatedUnfairLock(uncheckedState: State(stamper: stamper))
    }

    /// `tagarela.log` (índice 0) é o corrente; 1..n são os rotacionados.
    func fileURL(index: Int) -> URL {
        let name = index == 0 ? "\(baseName).\(ext)" : "\(baseName).\(index).\(ext)"
        return directory.appendingPathComponent(name)
    }

    func append(level: String, category: String, message: String) {
        state.withLock { s in
            let line = "\(s.stamper.string(from: Date())) \(level.uppercased()) [\(category)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            openIfNeeded(&s)
            if s.size > 0 && s.size + data.count > maxBytes {
                rotate(&s)
                openIfNeeded(&s)
            }
            guard let handle = s.handle else { return }
            do {
                try handle.write(contentsOf: data)
                s.size += data.count
            } catch {
                // Diagnóstico nunca pode derrubar o app. Solta o handle pra
                // tentar reabrir na próxima linha.
                try? handle.close()
                s.handle = nil
            }
        }
    }

    /// Últimas `limit` linhas, atravessando os arquivos rotacionados quando o
    /// corrente não tem o suficiente.
    func contents(limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        return state.withLock { s -> [String] in
            try? s.handle?.synchronize()
            var result: [String] = []
            var index = 0
            while index < maxFiles && result.count < limit {
                let url = fileURL(index: index)
                index += 1
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let lines = text.split(separator: "\n").map(String.init)
                result = Array(lines.suffix(limit - result.count)) + result
            }
            return result
        }
    }

    private func openIfNeeded(_ s: inout State) {
        guard s.handle == nil else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = fileURL(index: 0)
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        s.handle = handle
        s.size = Int((try? handle.seekToEnd()) ?? 0)
    }

    /// Descarta o mais antigo e empurra os demais um índice para trás.
    private func rotate(_ s: inout State) {
        try? s.handle?.close()
        s.handle = nil
        s.size = 0
        let fm = FileManager.default
        try? fm.removeItem(at: fileURL(index: maxFiles - 1))
        var index = maxFiles - 2
        while index >= 0 {
            let from = fileURL(index: index)
            if fm.fileExists(atPath: from.path) {
                try? fm.moveItem(at: from, to: fileURL(index: index + 1))
            }
            index -= 1
        }
    }
}
