import CoreGraphics
import Foundation
let targetPID = Int32(CommandLine.arguments.dropFirst().first ?? "") ?? (Int32(String(data: (try? { let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep"); p.arguments = ["-x", "Tagarela"]; let pipe = Pipe(); p.standardOutput = pipe; try p.run(); p.waitUntilExit(); return pipe.fileHandleForReading.readDataToEndOfFile() }()) ?? Data(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0)
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
var n = 0
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == targetPID {
    n += 1
    let on = w[kCGWindowIsOnscreen as String] as? Bool ?? false
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let name = w[kCGWindowName as String] as? String ?? ""
    let alpha = w[kCGWindowAlpha as String] as? Double ?? -1
    let mem = w[kCGWindowMemoryUsage as String] as? Int ?? -1
    print("window id=\(w[kCGWindowNumber as String] ?? 0) onscreen=\(on) layer=\(layer) alpha=\(alpha) name='\(name)' bounds=\(bounds) mem=\(mem)")
}
print("total windows owned by pid \(targetPID): \(n)")
