// tools/audit_strings.swift — uso: swift tools/audit_strings.swift
// Lista candidatos a strings hardcoded user-facing nas views/services.
import Foundation

let root = "/Users/tars/Dev/tagarela/app/Tagarela"

let patterns = [
    #"Text\(\s*"([^"]+)"\s*\)"#,
    #"Button\(\s*"([^"]+)"\s*\)"#,
    #"Label\(\s*"([^"]+)"#,
    #"\.alert\(\s*"([^"]+)"#,
    #"messageText\s*=\s*"([^"]+)""#,
]

let fm = FileManager.default
let enumerator = fm.enumerator(atPath: root)!
var hits: [(file: String, line: Int, match: String)] = []

for case let path as String in enumerator where path.hasSuffix(".swift") {
    let full = (root as NSString).appendingPathComponent(path)
    guard let content = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
    let lines = content.components(separatedBy: "\n")
    for (idx, line) in lines.enumerated() {
        if line.contains("String(localized:") { continue }
        if line.contains("NSLocalizedString") { continue }
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: line) {
                hits.append((path, idx + 1, String(line[range])))
            }
        }
    }
}

hits.forEach { print("\($0.file):\($0.line)\t\($0.match)") }
print("\nTotal: \(hits.count) candidatos.")
