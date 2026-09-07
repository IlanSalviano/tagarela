import AVFoundation
import CoreAudio
import Foundation

func addr(_ sel: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}
func defaultInputDevice() -> AudioDeviceID? {
    var a = addr(kAudioHardwarePropertyDefaultInputDevice)
    var dev = AudioDeviceID(0); var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let st = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &dev)
    return st == noErr ? dev : nil
}
func deviceName(_ dev: AudioDeviceID) -> String {
    var a = addr(kAudioObjectPropertyName)
    var name: Unmanaged<CFString>? = nil; var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let st = AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &name)
    return st == noErr ? (name?.takeRetainedValue() as String? ?? "?") : "?"
}
func nominalRate(_ dev: AudioDeviceID) -> Double {
    var a = addr(kAudioDevicePropertyNominalSampleRate)
    var rate = Double(0); var size = UInt32(MemoryLayout<Double>.size)
    AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &rate); return rate
}
func setNominalRate(_ dev: AudioDeviceID, _ rate: Double) -> OSStatus {
    var a = addr(kAudioDevicePropertyNominalSampleRate); var r = rate
    return AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<Double>.size), &r)
}
func availableRates(_ dev: AudioDeviceID) -> [Double] {
    var a = addr(kAudioDevicePropertyAvailableNominalSampleRates)
    var size = UInt32(0)
    guard AudioObjectGetPropertyDataSize(dev, &a, 0, nil, &size) == noErr else { return [] }
    let n = Int(size) / MemoryLayout<AudioValueRange>.size
    var ranges = [AudioValueRange](repeating: AudioValueRange(), count: n)
    AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &ranges)
    return ranges.map { $0.mMinimum }
}
func spin(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

final class Capture {
    let engine = AVAudioEngine()
    var frames = 0; var buffers = 0; var peak: Float = 0
    var obs: NSObjectProtocol?
    init(tag: String) {
        obs = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { _ in
            print("  [\(tag)] *** AVAudioEngineConfigurationChange received (engine.isRunning=\(self.engine.isRunning))")
        }
    }
    func record(seconds: Double, label: String) {
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        print("[\(label)] inputNode.outputFormat(forBus:0) = \(fmt.sampleRate) Hz / \(fmt.channelCount) ch  (engine.isRunning=\(engine.isRunning))")
        frames = 0; buffers = 0; peak = 0
        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buf, _ in
            guard let self else { return }
            self.frames += Int(buf.frameLength); self.buffers += 1
            if let ch = buf.floatChannelData { for i in 0..<Int(buf.frameLength) { self.peak = max(self.peak, abs(ch[0][i])) } }
        }
        engine.prepare()
        do { try engine.start() } catch { print("[\(label)] engine.start() THREW: \(error)") }
        spin(seconds)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let claimedSec = fmt.sampleRate > 0 ? Double(frames) / fmt.sampleRate : 0
        print("[\(label)] buffers=\(buffers) frames=\(frames) → \(String(format: "%.2f", claimedSec))s of audio at claimed rate vs \(seconds)s wall; peak=\(peak)")
    }
}

print("mic auth status = \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue) (3=authorized)")
guard let dev = defaultInputDevice() else { print("no default input"); exit(1) }
let original = nominalRate(dev)
let rates = availableRates(dev)
print("default input: '\(deviceName(dev))' id=\(dev) nominal=\(original) Hz available=\(rates)")
let alt: Double = rates.contains(original == 48000 ? 16000 : 48000) ? (original == 48000 ? 16000 : 48000) : (rates.first { $0 != original } ?? original)
guard alt != original else { print("no alternative rate; abort"); exit(1) }

let cap = Capture(tag: "engine1")
cap.record(seconds: 1.0, label: "A baseline, engine1")

print("--- setting nominal rate \(original) -> \(alt) ...")
let st = setNominalRate(dev, alt); print("    status=\(st) now nominal=\(nominalRate(dev))")
spin(1.5)

cap.record(seconds: 1.0, label: "B same engine1 after rate change")
let fresh = Capture(tag: "engine2")
fresh.record(seconds: 1.0, label: "C FRESH engine2 after rate change")

print("--- restoring nominal rate -> \(original) ...")
let st2 = setNominalRate(dev, original); print("    status=\(st2) now nominal=\(nominalRate(dev))")
spin(1.5)
cap.record(seconds: 1.0, label: "D same engine1 after restore")
fresh.record(seconds: 1.0, label: "E engine2 after restore")
print("done; final nominal=\(nominalRate(dev))")
