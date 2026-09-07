import XCTest

/// A lista de chaves era **manual**, então não pegava as ausentes: a auditoria
/// de 2026-09-07 recontou 185 chaves usadas no código contra 149 no arquivo —
/// 37 ausentes, todas caindo silenciosamente no `defaultValue`. O arquivo não
/// era a fonte da verdade que dizia ser.
///
/// Agora as chaves são derivadas dos fontes.
final class LocalizableKeysTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TagarelaTests/
            .deletingLastPathComponent()   // app/
    }

    private var sourcesRoot: URL { repoRoot.appendingPathComponent("Tagarela", isDirectory: true) }

    private var stringsFile: URL {
        sourcesRoot
            .appendingPathComponent("Localization/pt-BR.lproj/Localizable.strings")
    }

    /// Chaves declaradas no `.strings`.
    private func declaredKeys() throws -> Set<String> {
        let text = try String(contentsOf: stringsFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^\s*"([^"]+)"\s*="#, options: [.anchorsMatchLines])
        return Set(matches(of: regex, in: text))
    }

    /// Chaves realmente usadas no código.
    private func usedKeys() throws -> [String: Set<String>] {
        let patterns = [
            #"String\(\s*localized:\s*"([^"]+)""#,
            #"NSLocalizedString\(\s*"([^"]+)""#,
        ].map { try! NSRegularExpression(pattern: $0) }

        var byFile: [String: Set<String>] = [:]
        let walker = FileManager.default.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil)
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for regex in patterns {
                for key in matches(of: regex, in: source) {
                    byFile[url.lastPathComponent, default: []].insert(key)
                }
            }
        }
        return byFile
    }

    private func matches(of regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    func test_everyKeyUsedInSourcesExistsInStrings() throws {
        guard FileManager.default.fileExists(atPath: sourcesRoot.path) else {
            throw XCTSkip("fontes do app indisponíveis a partir de #filePath")
        }
        let declared = try declaredKeys()
        let used = try usedKeys()

        var missing: [String] = []
        for (file, keys) in used.sorted(by: { $0.key < $1.key }) {
            for key in keys.sorted() where !declared.contains(key) {
                missing.append("\(key)  (\(file))")
            }
        }

        let total = used.values.reduce(into: Set<String>()) { $0.formUnion($1) }.count
        XCTAssertGreaterThan(total, 100, "varredura não encontrou os fontes")
        XCTAssertTrue(missing.isEmpty,
                      "\(missing.count) chave(s) usadas no código e ausentes do Localizable.strings:\n"
                      + missing.joined(separator: "\n"))
    }

    func test_noUnusedKeysInStrings() throws {
        guard FileManager.default.fileExists(atPath: sourcesRoot.path) else {
            throw XCTSkip("fontes do app indisponíveis a partir de #filePath")
        }
        let declared = try declaredKeys()
        let used = try usedKeys().values.reduce(into: Set<String>()) { $0.formUnion($1) }
        let unused = declared.subtracting(used).sorted()
        XCTAssertTrue(unused.isEmpty, "chave(s) no arquivo sem uso no código:\n" + unused.joined(separator: "\n"))
    }
}
