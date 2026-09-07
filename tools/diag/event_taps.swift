import CoreGraphics
import Foundation
var count: UInt32 = 0
_ = CGGetEventTapList(0, nil, &count)
var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
let err = CGGetEventTapList(count, &taps, &count)
print("CGGetEventTapList err=\(err.rawValue) taps=\(count)")
for t in taps.prefix(Int(count)) {
    let name = ProcessInfo.processInfo // placeholder
    _ = name
    var pname = "?"
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/ps"); p.arguments = ["-o", "comm=", "-p", "\(t.tappingProcess)"]
    let pipe = Pipe(); p.standardOutput = pipe; try? p.run(); p.waitUntilExit()
    pname = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
    let mark = (pname as NSString).lastPathComponent.hasPrefix("Tagarela") ? "  <=== TAGARELA" : ""
    print(String(format: "tap id=%u pid=%d (%@) enabled=%@ options=%u point=%u mask=0x%llx avgLat=%.0fus maxLat=%.0fus tapped=%d%@", t.eventTapID, t.tappingProcess, (pname as NSString).lastPathComponent, t.enabled ? "YES" : "NO", t.options.rawValue, t.tapPoint.rawValue, t.eventsOfInterest, t.avgUsecLatency, t.maxUsecLatency, t.processBeingTapped, mark))
}
